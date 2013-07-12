#!/usr/bin/python
# -*- encoding: utf-8; py-indent-offset: 4 -*-
# +------------------------------------------------------------------+
# |             ____ _               _        __  __ _  __           |
# |            / ___| |__   ___  ___| | __   |  \/  | |/ /           |
# |           | |   | '_ \ / _ \/ __| |/ /   | |\/| | ' /            |
# |           | |___| | | |  __/ (__|   <    | |  | | . \            |
# |            \____|_| |_|\___|\___|_|\_\___|_|  |_|_|\_\           |
# |                                                                  |
# | Copyright Mathias Kettner 2013             mk@mathias-kettner.de |
# +------------------------------------------------------------------+
#
# This file is part of Check_MK.
# The official homepage is at http://mathias-kettner.de/check_mk.
#
# check_mk is free software;  you can redistribute it and/or modify it
# under the  terms of the  GNU General Public License  as published by
# the Free Software Foundation in version 2.  check_mk is  distributed
# in the hope that it will be useful, but WITHOUT ANY WARRANTY;  with-
# out even the implied warranty of  MERCHANTABILITY  or  FITNESS FOR A
# PARTICULAR PURPOSE. See the  GNU General Public License for more de-
# ails.  You should have  received  a copy of the  GNU  General Public
# License along with GNU Make; see the file  COPYING.  If  not,  write
# to the Free Software Foundation, Inc., 51 Franklin St,  Fifth Floor,
# Boston, MA 02110-1301 USA.

import socket, os, sys, time, re, signal, math, tempfile, gearman, base64
from Crypto.Cipher import AES

# Python 2.3 does not have 'set' in normal namespace.
# But it can be imported from 'sets'
try:
    set()
except NameError:
    from sets import Set as set

# colored output, if stdout is a tty
if sys.stdout.isatty():
    tty_red       = '\033[31m'
    tty_green     = '\033[32m'
    tty_yellow    = '\033[33m'
    tty_blue      = '\033[34m'
    tty_magenta   = '\033[35m'
    tty_cyan      = '\033[36m'
    tty_white     = '\033[37m'
    tty_bgblue    = '\033[44m'
    tty_bgmagenta = '\033[45m'
    tty_bgwhite   = '\033[47m'
    tty_bold      = '\033[1m'
    tty_underline = '\033[4m'
    tty_normal    = '\033[0m'
    tty_ok        = tty_green + tty_bold + 'OK' + tty_normal
    def tty(fg=-1, bg=-1, attr=-1):
        if attr >= 0:
            return "\033[3%d;4%d;%dm" % (fg, bg, attr)
        elif bg >= 0:
            return "\033[3%d;4%dm" % (fg, bg)
        elif fg >= 0:
            return "\033[3%dm" % fg
        else:
            return tty_normal
else:
    tty_red       = ''
    tty_green     = ''
    tty_yellow    = ''
    tty_blue      = ''
    tty_magenta   = ''
    tty_cyan      = ''
    tty_white     = ''
    tty_bgblue    = ''
    tty_bgmagenta = ''
    tty_bold      = ''
    tty_underline = ''
    tty_normal    = ''
    tty_ok        = 'OK'
    def tty(fg=-1, bg=-1, attr=-1):
        return ''

# global variables used to cache temporary values
g_dns_cache                  = {}
g_infocache                  = {} # In-memory cache of host info.
g_agent_already_contacted    = {} # do we have agent data from this host?
g_counters                   = {} # storing counters of one host
g_hostname                   = "unknown" # Host currently being checked
g_aggregated_service_results = {}   # store results for later submission
compiled_regexes             = {}   # avoid recompiling regexes
nagios_command_pipe          = None # Filedescriptor to open nagios command pipe.
checkresult_file_fd          = None
checkresult_file_path        = None
g_single_oid_hostname        = None
g_single_oid_cache           = {}
g_broken_snmp_hosts          = set([])
g_broken_agent_hosts         = set([])


# variables set later by getopt
opt_dont_submit              = False
opt_showplain                = False
opt_showperfdata             = False
opt_use_cachefile            = False
opt_no_tcp                   = False
opt_no_cache                 = False
opt_no_snmp_hosts            = False
opt_use_snmp_walk            = False
opt_cleanup_autochecks       = False
fake_dns                     = False

# register SIGINT handler for consistenct CTRL+C handling
def interrupt_handler(signum, frame):
    sys.stderr.write('<Interrupted>\n')
    sys.exit(1)
signal.signal(signal.SIGINT, interrupt_handler)

class MKGeneralException(Exception):
    def __init__(self, reason):
        self.reason = reason
    def __str__(self):
        return self.reason

class MKCounterWrapped(Exception):
    def __init__(self, countername, reason):
        self.name = countername
        self.reason = reason
    def __str__(self):
        return '%s: %s' % (self.name, self.reason)

class MKAgentError(Exception):
    def __init__(self, reason):
        self.reason = reason
    def __str__(self):
        return self.reason

class MKSNMPError(Exception):
    def __init__(self, reason):
        self.reason = reason
    def __str__(self):
        return self.reason

#   +----------------------------------------------------------------------+
#   |         _                                    _   _                   |
#   |        / \   __ _  __ _ _ __ ___  __ _  __ _| |_(_) ___  _ __        |
#   |       / _ \ / _` |/ _` | '__/ _ \/ _` |/ _` | __| |/ _ \| '_ \       |
#   |      / ___ \ (_| | (_| | | |  __/ (_| | (_| | |_| | (_) | | | |      |
#   |     /_/   \_\__, |\__, |_|  \___|\__, |\__,_|\__|_|\___/|_| |_|      |
#   |             |___/ |___/          |___/                               |
#   +----------------------------------------------------------------------+

# Compute the name of a summary host
def summary_hostname(hostname):
    return aggr_summary_hostname % hostname

# Updates the state of an aggregated service check from the output of
# one of the underlying service checks. The status of the aggregated
# service will be updated such that the new status is the maximum
# (crit > unknown > warn > ok) of all underlying status. Appends the output to
# the output list and increases the count by 1.
def store_aggregated_service_result(hostname, detaildesc, aggrdesc, newstatus, newoutput):
    global g_aggregated_service_results
    count, status, outputlist = g_aggregated_service_results.get(aggrdesc, (0, 0, []))
    if status_worse(newstatus, status):
        status = newstatus
    if newstatus > 0 or aggregation_output_format == "multiline":
        outputlist.append( (newstatus, detaildesc, newoutput) )
    g_aggregated_service_results[aggrdesc] = (count + 1, status, outputlist)

def status_worse(newstatus, status):
    if status == 2:
        return False # nothing worse then critical
    elif newstatus == 2:
        return True  # nothing worse then critical
    else:
        return newstatus > status # 0 < 1 < 3 are in correct order

# Submit the result of all aggregated services of a host
# to Nagios. Those are stored in g_aggregated_service_results
def submit_aggregated_results(hostname):
    if not host_is_aggregated(hostname):
        return

    if opt_verbose:
        print "\n%s%sAggregates Services:%s" % (tty_bold, tty_blue, tty_normal)
    global g_aggregated_service_results
    items = g_aggregated_service_results.items()
    items.sort()
    aggr_hostname = summary_hostname(hostname)
    for servicedesc, (count, status, outputlist) in items:
        if aggregation_output_format == "multiline":
            longoutput = ""
            statuscounts = [ 0, 0, 0, 0 ]
            for itemstatus, item, output in outputlist:
                longoutput += '\\n%s: %s' % (item, output)
                statuscounts[itemstatus] = statuscounts[itemstatus] + 1
            summarytexts = [ "%d service%s %s" % (x[0], x[0] != 1 and "s" or "", x[1])
                           for x in zip(statuscounts, ["OK", "WARN", "CRIT", "UNKNOWN" ]) if x[0] > 0 ]
            text = ", ".join(summarytexts) + longoutput
        else:
            if status == 0:
                text = "OK - %d services OK" % count
            else:
                text = " *** ".join([ item + " " + output for itemstatus, item, output in outputlist ])

        if not opt_dont_submit:
            submit_to_nagios(aggr_hostname, servicedesc, status, text)

        if opt_verbose:
            color = { 0: tty_green, 1: tty_yellow, 2: tty_red, 3: tty_magenta }[status]
            lines = text.split('\\n')
            print "%-20s %s%s%-70s%s" % (servicedesc, tty_bold, color, lines[0], tty_normal)
            if len(lines) > 1:
                for line in lines[1:]:
                    print "  %s" % line
                print "-------------------------------------------------------------------------------"



def submit_check_mk_aggregation(hostname, status, output):
    if not host_is_aggregated(hostname):
        return

    if not opt_dont_submit:
        submit_to_nagios(summary_hostname(hostname), "Check_MK", status, output)

    if opt_verbose:
        color = { 0: tty_green, 1: tty_yellow, 2: tty_red, 3: tty_magenta }[status]
        print "%-20s %s%s%-70s%s" % ("Check_MK", tty_bold, color, output, tty_normal)




#   +----------------------------------------------------------------------+
#   |                 ____      _         _       _                        |
#   |                / ___| ___| |_    __| | __ _| |_ __ _                 |
#   |               | |  _ / _ \ __|  / _` |/ _` | __/ _` |                |
#   |               | |_| |  __/ |_  | (_| | (_| | || (_| |                |
#   |                \____|\___|\__|  \__,_|\__,_|\__\__,_|                |
#   |                                                                      |
#   +----------------------------------------------------------------------+


# This is the main function for getting information needed by a
# certain check. It is called once for each check type. For SNMP this
# is needed since not all data for all checks is fetched at once. For
# TCP based checks the first call to this function stores the
# retrieved data in a global variable. Later calls to this function
# get their data from there.

# If the host is a cluster, the information is fetched from all its
# nodes an then merged per-check-wise.

# For cluster checks we do not have an ip address from Nagios
# We need to do DNS-lookups in that case :-(. We could avoid that at
# least in case of precompiled checks. On the other hand, cluster checks
# usually use existing cache files, if check_mk is not misconfigured,
# and thus do no network activity at all...

def get_host_info(hostname, ipaddress, checkname):

    # If the check want's the node info, we add an additional
    # column (as the first column) with the name of the node
    # or None (in case of non-clustered nodes). On problem arises,
    # if we deal with subchecks. We assume that all subchecks
    # have the same setting here. If not, let's raise an exception.
    add_nodeinfo = check_info.get(checkname, {}).get("node_info", False)

    nodes = nodes_of(hostname)
    if nodes != None:
        info = []
        at_least_one_without_exception = False
        exception_texts = []
        global opt_use_cachefile
        opt_use_cachefile = True
	is_snmp_error = False
        for node in nodes:
            # If an error with the agent occurs, we still can (and must)
            # try the other node.
            try:
                ipaddress = lookup_ipaddress(node)
                new_info = get_realhost_info(node, ipaddress, checkname, cluster_max_cachefile_age)
                if add_nodeinfo:
                    new_info = [ [node] + line for line in new_info ]
                info += new_info
                at_least_one_without_exception = True
            except MKAgentError, e:
		if str(e) != "": # only first error contains text
                    exception_texts.append(str(e))
		g_broken_agent_hosts.add(node)
            except MKSNMPError, e:
		if str(e) != "": # only first error contains text
		    exception_texts.append(str(e))
		g_broken_snmp_hosts.add(node)
		is_snmp_error = True
        if not at_least_one_without_exception:
	    if is_snmp_error:
                raise MKSNMPError(", ".join(exception_texts))
            else:
                raise MKAgentError(", ".join(exception_texts))
        return info
    else:
        info = get_realhost_info(hostname, ipaddress, checkname, check_max_cachefile_age)
        if add_nodeinfo:
            return [ [ None ] + line for line in info ]
        else:
            return info

# Gets info from a real host (not a cluster). There are three possible
# ways: TCP, SNMP and external command.  This function raises
# MKAgentError or MKSNMPError, if there could not retrieved any data. It returns [],
# if the agent could be contacted but the data is empty (no items of
# this check type).
#
# What makes the thing a bit tricky is the fact, that data
# might have to be fetched via SNMP *and* TCP for one host
# (even if this is unlikeyly)
#
# This function assumes, that each check type is queried
# only once for each host.
def get_realhost_info(hostname, ipaddress, check_type, max_cache_age):
    info = get_cached_hostinfo(hostname)
    if info and info.has_key(check_type):
        return info[check_type]

    cache_relpath = hostname + "." + check_type

    # Is this an SNMP table check? Then snmp_info specifies the OID to fetch
    # Please note, that if the check_type is foo.bar then we lookup the
    # snmp info for "foo", not for "foo.bar".
    oid_info = snmp_info.get(check_type.split(".")[0])
    if oid_info:
        content = read_cache_file(cache_relpath, max_cache_age)
        if content:
            return eval(content)
        # Not cached -> need to get info via SNMP

        # Try to contact host only once
	if hostname in g_broken_snmp_hosts:
	    raise MKSNMPError("")

        # New in 1.1.3: oid_info can now be a list: Each element
        # of that list is interpreted as one real oid_info, fetches
        # a separate snmp table. The overall result is then the list
        # of these results.
        try:
            if type(oid_info) == list:
                table = [ get_snmp_table(hostname, ipaddress, entry) for entry in oid_info ]
                # if at least one query fails, we discard the hole table
                if None in table:
                    table = None
            else:
                table = get_snmp_table(hostname, ipaddress, oid_info)
        except:
            if opt_debug:
                raise
            else:
                raise MKGeneralException("Incomplete or invalid response from SNMP agent")

        store_cached_checkinfo(hostname, check_type, table)
        write_cache_file(cache_relpath, repr(table) + "\n")
        return table

    # No SNMP check. Then we must contact the check_mk_agent. Have we already
    # to get data from the agent? If yes we must not do that again! Even if
    # no cache file is present
    if g_agent_already_contacted.has_key(hostname):
	raise MKAgentError("")

    g_agent_already_contacted[hostname] = True
    store_cached_hostinfo(hostname, []) # leave emtpy info in case of error

    output = get_agent_info(hostname, ipaddress, max_cache_age)
    if len(output) == 0:
        raise MKAgentError("Empty output from agent")
    elif len(output) < 16:
        raise MKAgentError("Too short output from agent: '%s'" % output)

    lines = [ l.strip() for l in output.split('\n') ]
    info = parse_info(lines)
    store_cached_hostinfo(hostname, info)
    return info.get(check_type, []) # return only data for specified check


def read_cache_file(relpath, max_cache_age):
    # Cache file present, caching allowed? -> read from cache
    cachefile = tcp_cache_dir + "/" + relpath
    if os.path.exists(cachefile) and (
        (opt_use_cachefile and ( not opt_no_cache ) )
        or (simulation_mode and not opt_no_cache) ):
        if cachefile_age(cachefile) <= max_cache_age or simulation_mode:
            f = open(cachefile, "r")
            result = f.read(10000000)
            f.close()
            if len(result) > 0:
                if opt_debug:
                    sys.stderr.write("Using data from cachefile %s.\n" % cachefile)
                return result
        elif opt_debug:
            sys.stderr.write("Skipping cache file %s: Too old\n" % cachefile)

    if simulation_mode and not opt_no_cache:
        raise MKGeneralException("Simulation mode and no cachefile present.")

    if opt_no_tcp:
        raise MKGeneralException("Host is unreachable")
        #Cache file '%s' missing or too old. TCP disallowed by you." % cachefile)


def write_cache_file(relpath, output):
    cachefile = tcp_cache_dir + "/" + relpath
    if not os.path.exists(tcp_cache_dir):
        try:
            os.makedirs(tcp_cache_dir)
        except Exception, e:
            raise MKGeneralException("Cannot create directory %s: %s" % (tcp_cache_dir, e))
    try:
        # write retrieved information to cache file - if we are not root.
        # We assume that Nagios never runs as root.
        if not i_am_root():
            f = open(cachefile, "w+")
            f.write(output)
            f.close()
    except Exception, e:
        raise MKGeneralException("Cannot write cache file %s: %s" % (cachefile, e))


# Get information about a real host (not a cluster node) via TCP
# or by executing an external programm. ipaddress may be None.
# In that case it will be looked up if needed. Also caching will
# be handled here
def get_agent_info(hostname, ipaddress, max_cache_age):
    output = read_cache_file(hostname, max_cache_age)
    if not output:
        # Try to contact every host only once
        if hostname in g_broken_agent_hosts:
            raise MKAgentError("")

        # If the host ist listed in datasource_programs the data from
        # that host is retrieved by calling an external program (such
        # as ssh or rsy) instead of a TCP connect.
        commandline = get_datasource_program(hostname, ipaddress)
        if commandline:
            output = get_agent_info_program(commandline)
        else:
            output = get_agent_info_tcp(hostname, ipaddress)

        # Got new data? Write to cache file
        write_cache_file(hostname, output)

    if agent_simulator:
        output = agent_simulator_process(output)

    return output

# Get data in case of external programm
def get_agent_info_program(commandline):
    if opt_verbose:
        sys.stderr.write("Calling external programm %s\n" % commandline)
    try:
        sout = os.popen(commandline + " 2>/dev/null")
        output = sout.read()
        exitstatus = sout.close()
    except Exception, e:
        raise MKAgentError("Could not execute '%s': %s" % (commandline, e))

    if exitstatus:
        if exitstatus >> 8 == 127:
            raise MKAgentError("Programm '%s' not found (exit code 127)" % (commandline,))
        else:
            raise MKAgentError("Programm '%s' exited with code %d" % (commandline, exitstatus >> 8))
    return output

# Get data in case of TCP
def get_agent_info_tcp(hostname, ipaddress):
    if not ipaddress:
        raise MKGeneralException("Cannot contact agent: host '%s' has no IP address." % hostname)
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            s.settimeout(tcp_connect_timeout)
        except:
            pass # some old Python versions lack settimeout(). Better ignore than fail
        s.connect((ipaddress, agent_port_of(hostname)))
        try:
            s.setblocking(1)
        except:
            pass
        output = ""
        while True:
            out = s.recv(4096, socket.MSG_WAITALL)
            if out and len(out) > 0:
                output += out
            else:
                break
        s.close()
        if len(output) == 0: # may be caused by xinetd not allowing our address
            raise MKAgentError("Empty output from agent at TCP port %d" %
                  agent_port_of(hostname))
        return output
    except MKAgentError, e:
        raise
    except Exception, e:
        raise MKAgentError("Cannot get data from TCP port %s:%d: %s" %
                           (ipaddress, agent_port_of(hostname), e))


# Gets all information about one host so far cached.
# Returns None if nothing has been stored so far
def get_cached_hostinfo(hostname):
    global g_infocache
    return g_infocache.get(hostname, None)

# store complete information about a host
def store_cached_hostinfo(hostname, info):
    global g_infocache
    oldinfo = get_cached_hostinfo(hostname)
    if oldinfo:
        oldinfo.update(info)
        g_infocache[hostname] = oldinfo
    else:
        g_infocache[hostname] = info

# store information about one check type
def store_cached_checkinfo(hostname, checkname, table):
    global g_infocache
    info = get_cached_hostinfo(hostname)
    if info:
        info[checkname] = table
    else:
        g_infocache[hostname] = { checkname: table }

# Split agent output in chunks, splits lines by whitespaces
def parse_info(lines):
    info = {}
    chunk = []
    chunkoptions = {}
    separator = None
    for line in lines:
        if line[:3] == '<<<' and line[-3:] == '>>>':
            chunkheader = line[3:-3]
            # chunk header has format <<<name:opt1(args):opt2:opt3(args)>>>
            headerparts = chunkheader.split(":")
            chunkname = headerparts[0]
            chunkoptions = {}
            for o in headerparts[1:]:
                opt_parts = o.split("(")
                opt_name = opt_parts[0]
                if len(opt_parts) > 1:
                    opt_args = opt_parts[1][:-1]
                else:
                    opt_args = None
                chunkoptions[opt_name] = opt_args

            chunk = info.get(chunkname, None)
            if chunk == None: # chunk appears in output for the first time
                chunk = []
                info[chunkname] = chunk
            try:
                separator = chr(int(chunkoptions["sep"]))
            except:
                separator = None
        elif line != '':
            chunk.append(line.split(separator))
    return info


def cachefile_age(filename):
    try:
        return time.time() - os.stat(filename)[8]
    except Exception, e:
        raise MKGeneralException("Cannot determine age of cache file %s: %s" \
                                 % (filename, e))
        return -1

#   +----------------------------------------------------------------------+
#   |                ____                  _                               |
#   |               / ___|___  _   _ _ __ | |_ ___ _ __ ___                |
#   |              | |   / _ \| | | | '_ \| __/ _ \ '__/ __|               |
#   |              | |__| (_) | |_| | | | | ||  __/ |  \__ \               |
#   |               \____\___/ \__,_|_| |_|\__\___|_|  |___/               |
#   |                                                                      |
#   +----------------------------------------------------------------------+


# Variable                 time_t    value
# netctr.eth.tx_collisions 112354335 818
def load_counters(hostname):
    global g_counters
    filename = counters_directory + "/" + hostname
    try:
        g_counters = eval(file(filename).read())
    except:
        # Try old syntax
        try:
            lines = file(filename).readlines()
            for line in lines:
                line = line.split()
                g_counters[' '.join(line[0:-2])] = ( int(line[-2]), int(line[-1]) )
        except:
            g_counters = {}

def get_counter(countername, this_time, this_val, allow_negative=False):
    global g_counters

    # First time we see this counter? Do not return
    # any data!
    if not countername in g_counters:
        g_counters[countername] = (this_time, this_val)
        # Do not suppress this check on check_mk -nv
        if opt_dont_submit:
            return 1.0, 0.0
        raise MKCounterWrapped(countername, 'Counter initialization')

    last_time, last_val = g_counters.get(countername)
    timedif = this_time - last_time
    if timedif <= 0: # do not update counter
        # Reset counter to a (hopefully) reasonable value
        g_counters[countername] = (this_time, this_val)
        # Do not suppress this check on check_mk -nv
        if opt_dont_submit:
            return 1.0, 0.0
        raise MKCounterWrapped(countername, 'No time difference')

    # update counter for next time
    g_counters[countername] = (this_time, this_val)

    valuedif = this_val - last_val
    if valuedif < 0 and not allow_negative:
        # Do not try to handle wrapper counters. We do not know
        # wether they are 32 or 64 bit. It also could happen counter
        # reset (reboot, etc.). Better is to leave this value undefined
        # and wait for the next check interval.
        # Do not suppress this check on check_mk -nv
        if opt_dont_submit:
            return 1.0, 0.0
        raise MKCounterWrapped(countername, 'Value overflow')

    per_sec = float(valuedif) / timedif
    return timedif, per_sec


# Compute average by gliding exponential algorithm
# itemname: unique id for storing this average until the next check
# this_time: timestamp of new value
# backlog: averaging horizon in minutes
# initialize_zero: assume average of 0.0 when now previous average is stored
def get_average(itemname, this_time, this_val, backlog, initialize_zero = True):

    # first call: take current value as average or assume 0.0
    if not itemname in g_counters:
        if initialize_zero:
            this_val = 0
        g_counters[itemname] = (this_time, this_val)
        return 1.0, this_val # avoid time diff of 0.0 -> avoid division by zero

    # Get previous value and time difference
    last_time, last_val = g_counters.get(itemname)
    timedif = this_time - last_time

    # Compute the weight: We do it like this: First we assume that
    # we get one sample per minute. And that backlog is the number
    # of minutes we should average over. Then we want that the weight
    # of the values of the last average minutes have a fraction of W%
    # in the result and the rest until infinity the rest (1-W%).
    # Then the weight can be computed as backlog'th root of 1-W
    percentile = 0.50

    weight_per_minute = (1 - percentile) ** (1.0 / backlog)

    # now let's compute the weight per second. This is done
    weight = weight_per_minute ** (timedif / 60.0)

    new_val = last_val * weight + this_val * (1 - weight)

    # print "Alt: %.5f, Jetzt: %.5f, Timedif: %.1f, Gewicht: %.5f, Neu: %.5f" % \
    #     (last_val, this_val, timedif, weight, new_val)

    g_counters[itemname] = (this_time, new_val)
    return timedif, new_val


def save_counters(hostname):
    if not opt_dont_submit and not i_am_root(): # never writer counters as root
        global g_counters
        filename = counters_directory + "/" + hostname
        try:
            if not os.path.exists(counters_directory):
                os.makedirs(counters_directory)
            file(filename, "w").write("%r\n" % g_counters)
        except Exception, e:
            raise MKGeneralException("User %s cannot write to %s: %s" % (username(), filename, e))

# writelines([ "%s %d %d\n" % (i[0], i[1][0], i[1][1]) for i in g_counters.items() ])


#   +----------------------------------------------------------------------+
#   |               ____ _               _    _                            |
#   |              / ___| |__   ___  ___| | _(_)_ __   __ _                |
#   |             | |   | '_ \ / _ \/ __| |/ / | '_ \ / _` |               |
#   |             | |___| | | |  __/ (__|   <| | | | | (_| |               |
#   |              \____|_| |_|\___|\___|_|\_\_|_| |_|\__, |               |
#   |                                                 |___/                |
#   |                                                                      |
#   | All about performing the actual checks and send the data to Nagios.  |
#   +----------------------------------------------------------------------+

# This is the main check function - the central entry point to all and
# everything
def do_check(hostname, ipaddress, only_check_types = None):

    if opt_verbose:
        sys.stderr.write("Check_mk version %s\n" % check_mk_version)

    start_time = time.time()

    try:
        load_counters(hostname)
        agent_version, num_success, error_sections, problems = do_all_checks_on_host(hostname, ipaddress, only_check_types)
        num_errors = len(error_sections)
        save_counters(hostname)
        if problems:
	    output = "CRIT - %s, " % problems
            status = 2
        elif num_errors > 0 and num_success > 0:
            output = "WARN - Missing agent sections: %s - " % ", ".join(error_sections)
            status = 1
        elif num_errors > 0:
            output = "CRIT - Got no information from host, "
            status = 2
        elif agent_min_version and agent_version < agent_min_version:
            output = "WARN - old plugin version %s (should be at least %s), " % (agent_version, agent_min_version)
            status = 1
        else:
            output = "OK - "
            if agent_version != None:
                output += "Agent version %s, " % agent_version
            status = 0

    except MKGeneralException, e:
        if opt_debug:
            raise
        output = "UNKNOWN - %s, " % e
        status = 3

    if aggregate_check_mk:
        try:
            submit_check_mk_aggregation(hostname, status, output)
        except:
            if opt_debug:
                raise

    if checkresult_file_fd != None:
        close_checkresult_file()

    run_time = time.time() - start_time
    if check_mk_perfdata_with_times:
        times = os.times()
        output += "execution time %.1f sec|execution_time=%.3f user_time=%.3f "\
                  "system_time=%.3f children_user_time=%.3f children_system_time=%.3f\n" %\
                (run_time, run_time, times[0], times[1], times[2], times[3])
    else:
        output += "execution time %.1f sec|execution_time=%.3f\n" % (run_time, run_time)

    sys.stdout.write(output)
    sys.exit(status)

def check_unimplemented(checkname, params, info):
    return (3, 'UNKNOWN - Check not implemented')

def convert_check_info():
    for check_type, info in check_info.items():
        basename = check_type.split(".")[0]

        if type(info) != dict:
            # Convert check declaration from old style to new API
            check_function, service_description, has_perfdata, inventory_function = info
            if inventory_function == no_inventory_possible:
                inventory_function = None

            check_info[check_type] = {
                "check_function"          : check_function,
                "service_description"     : service_description,
                "has_perfdata"            : not not has_perfdata,
                "inventory_function"      : inventory_function,
                # Insert check name as group if no group is being defined
                "group"                   : checkgroup_of.get(check_type, check_type),
                "snmp_info"               : snmp_info.get(check_type),
                # Sometimes the scan function is assigned to the check_type
                # rather than to the base name.
                "snmp_scan_function"      :
                    snmp_scan_functions.get(check_type,
                        snmp_scan_functions.get(basename)),
                "default_levels_variable" : check_default_levels.get(check_type),
                "node_info"               : False,
            }
        else:
            # Check does already use new API. Make sure that all keys are present,
            # extra check-specific information into file-specific variables.
            info.setdefault("inventory_function", None)
            info.setdefault("group", None)
            info.setdefault("snmp_info", None)
            info.setdefault("snmp_scan_function", None)
            info.setdefault("default_levels_variable", None)
            info.setdefault("node_info", False)

            # Include files are related to the check file (= the basename),
            # not to the (sub-)check. So we keep them in check_includes.
            check_includes.setdefault(basename, [])
            check_includes[basename] += info.get("includes", [])

    # Make sure that setting for node_info of check and subcheck matches
    for check_type, info in check_info.iteritems():
        if "." in check_type:
            base_check = check_type.split(".")[0]
            if base_check not in check_info:
                if info["node_info"]:
                    raise MKGeneralException("Invalid check implementation: node_info for %s is True, but base check %s not defined" %
                        (check_type, base_check))
            elif check_info[base_check]["node_info"] != info["node_info"]:
               raise MKGeneralException("Invalid check implementation: node_info for %s and %s are different." % (
                   (base_check, check_type)))

    # Now gather snmp_info and snmp_scan_function back to the
    # original arrays. Note: these information is tied to a "agent section",
    # not to a check. Several checks may use the same SNMP info and scan function.
    for check_type, info in check_info.iteritems():
        basename = check_type.split(".")[0]
        if info["snmp_info"] and basename not in snmp_info:
            snmp_info[basename] = info["snmp_info"]
        if info["snmp_scan_function"] and basename not in snmp_scan_functions:
            snmp_scan_functions[basename] = info["snmp_scan_function"]

# Loops over all checks for a host, gets the data, calls the check
# function that examines that data and sends the result to Nagios
def do_all_checks_on_host(hostname, ipaddress, only_check_types = None):
    global g_aggregated_service_results
    g_aggregated_service_results = {}
    global g_hostname
    g_hostname = hostname
    num_success = 0
    error_sections = set([])
    check_table = get_sorted_check_table(hostname)
    problems = []

    for checkname, item, params, description, info in check_table:
        if only_check_types != None and checkname not in only_check_types:
            continue

        # Skip checks that are not in their check period
        period = check_period_of(hostname, description)
        if period and not check_timeperiod(period):
            if opt_debug:
                sys.stderr.write("Skipping service %s: currently not in timeperiod %s.\n" %
                        (description, period))
            continue
        elif period and opt_debug:
            sys.stderr.write("Service %s: timeperiod %s is currently active.\n" %
                    (description, period))

        # In case of a precompiled check table info is the aggrated
        # service name. In the non-precompiled version there are the dependencies
        if type(info) == str:
            aggrname = info
        else:
            aggrname = aggregated_service_name(hostname, description)

        infotype = checkname.split('.')[0]
        try:
	    info = get_host_info(hostname, ipaddress, infotype)
        except MKSNMPError, e:
	    if str(e):
	        problems.append(str(e))
            error_sections.add(infotype)
	    g_broken_snmp_hosts.add(hostname)
	    continue

        except MKAgentError, e:
	    if str(e):
                problems.append(str(e))
            error_sections.add(infotype)
	    g_broken_agent_hosts.add(hostname)
	    continue

        if info or info == []:
            num_success += 1
            try:
                check_function = check_info[checkname]["check_function"]
            except:
                check_function = check_unimplemented

            try:
                dont_submit = False
                result = check_function(item, params, info)
            # handle check implementations that do not yet support the
            # handling of wrapped counters via exception. Do not submit
            # any check result in that case:
            except MKCounterWrapped, e:
                if opt_verbose:
                    print "Counter wrapped, not handled by check, ignoring this check result: %s" % e
                dont_submit = True
            except Exception, e:
                result = (3, "invalid output from agent, invalid check parameters or error in implementation of check %s. Please set <tt>debug_log</tt> to a filename in <tt>main.mk</tt> for enabling exception logging." % checkname)
                if debug_log:
                    try:
                        import traceback, pprint
                        l = file(debug_log, "a")
                        l.write(("Invalid output from plugin or error in check:\n"
                                "  Check_MK Version: %s\n"
                                "  Date:             %s\n"
                                "  Host:             %s\n"
                                "  Service:          %s\n"
                                "  Check type:       %s\n"
                                "  Item:             %r\n"
                                "  Parameters:       %s\n"
                                "  %s\n"
                                "  Agent info:       %s\n\n") % (
                                check_mk_version,
                                time.strftime("%Y-%d-%m %H:%M:%S"),
                                hostname, description, checkname, item, pprint.pformat(params),
                                traceback.format_exc().replace('\n', '\n      '),
                                pprint.pformat(info)))
                    except:
                        pass

                if opt_debug:
                    raise
            if not dont_submit:
                submit_check_result(hostname, description, result, aggrname)
        else:
            error_sections.add(infotype)

    submit_aggregated_results(hostname)

    try:
        if is_tcp_host(hostname):
            version_info = get_host_info(hostname, ipaddress, 'check_mk')
            agent_version = version_info[0][1]
        else:
            agent_version = None
    except MKAgentError, e:
	g_broken_agent_hosts.add(hostname)
        agent_version = "(unknown)"
    except:
        agent_version = "(unknown)"
    error_sections = list(error_sections)
    error_sections.sort()
    return agent_version, num_success, error_sections, ", ".join(problems)



def open_checkresult_file():
    global checkresult_file_fd
    global checkresult_file_path
    if checkresult_file_fd == None:
        try:
            checkresult_file_fd, checkresult_file_path = \
                tempfile.mkstemp('', 'c', check_result_path)
        except Exception, e:
            raise MKGeneralException("Cannot create check result file in %s: %s" %
                    (check_result_path, e))


def close_checkresult_file():
    global checkresult_file_fd
    if checkresult_file_fd != None:
        os.close(checkresult_file_fd)
        file(checkresult_file_path + ".ok", "w")
        checkresult_file_fd = None


def nagios_pipe_open_timeout(signum, stackframe):
    raise IOError("Timeout while opening pipe")


def open_command_pipe():
    global nagios_command_pipe
    if nagios_command_pipe == None:
        if not os.path.exists(nagios_command_pipe_path):
            nagios_command_pipe = False # False means: tried but failed to open
            raise MKGeneralException("Missing Nagios command pipe '%s'" % nagios_command_pipe_path)
        else:
            try:
                signal.signal(signal.SIGALRM, nagios_pipe_open_timeout)
                signal.alarm(3) # three seconds to open pipe
                nagios_command_pipe =  file(nagios_command_pipe_path, 'w')
                signal.alarm(0) # cancel alarm
            except Exception, e:
                nagios_command_pipe = False
                raise MKGeneralException("Error writing to command pipe: %s" % e)



def convert_perf_value(x):
    if x == None:
        return ""
    elif type(x) in [ str, unicode ]:
        return x
    elif type(x) == float:
        return ("%.6f" % x).rstrip("0").rstrip(".")
    else:
        return str(x)

def convert_perf_data(p):
    # replace None with "" and fill up to 7 values
    p = (map(convert_perf_value, p) + ['','','',''])[0:6]
    return "%s=%s;%s;%s;%s;%s" %  tuple(p)


def submit_check_result(host, servicedesc, result, sa):
    if len(result) >= 3:
        state, infotext, perfdata = result[:3]
    else:
        state, infotext = result
        perfdata = None

    if not (
        infotext.startswith("OK -") or
        infotext.startswith("WARN -") or
        infotext.startswith("CRIT -") or
        infotext.startswith("UNKNOWN -")):
        infotext = nagios_state_names[state] + " - " + infotext

    global nagios_command_pipe
    # [<timestamp>] PROCESS_SERVICE_CHECK_RESULT;<host_name>;<svc_description>;<return_code>;<plugin_output>

    # Aggregated service -> store for later
    if sa != "":
        store_aggregated_service_result(host, servicedesc, sa, state, infotext)

    # performance data - if any - is stored in the third part of the result
    perftexts = [];
    perftext = ""

    if perfdata:
        # Check may append the name of the check command to the
        # list of perfdata. It is of type string. And it might be
        # needed by the graphing tool in order to choose the correct
        # template. Currently this is used only by mrpe.
        if len(perfdata) > 0 and type(perfdata[-1]) == str:
            check_command = perfdata[-1]
            del perfdata[-1]
        else:
            check_command = None

        for p in perfdata:
            perftexts.append(convert_perf_data(p))

        if perftexts != []:
            if check_command and perfdata_format == "pnp":
                perftexts.append("[%s]" % check_command)
            perftext = "|" + (" ".join(perftexts))

    if not opt_dont_submit:
        submit_to_nagios(host, servicedesc, state, infotext + perftext)

    if opt_verbose:
        if opt_showperfdata:
            p = ' (%s)' % (" ".join(perftexts))
        else:
            p = ''
        color = { 0: tty_green, 1: tty_yellow, 2: tty_red, 3: tty_magenta }[state]
        print "%-20s %s%s%-56s%s%s" % (servicedesc, tty_bold, color, infotext, tty_normal, p)


def submit_to_nagios(host, service, state, output):
    if check_submission == "pipe":
        open_command_pipe()
        if nagios_command_pipe:
            nagios_command_pipe.write("[%d] PROCESS_SERVICE_CHECK_RESULT;%s;%s;%d;%s\n" %
                                   (int(time.time()), host, service, state, output)  )
            # Important: Nagios needs the complete command in one single write() block!
            # Python buffers and sends chunks of 4096 bytes, if we do not flush.
            nagios_command_pipe.flush()
    elif check_submission == "file":
        open_checkresult_file()
        if checkresult_file_fd:
            now = time.time()
            os.write(checkresult_file_fd,
                """host_name=%s
service_description=%s
check_type=1
check_options=0
reschedule_check
latency=0.0
start_time=%.1f
finish_time=%.1f
return_code=%d
output=%s

""" % (host, service, now, now, state, output))
    elif check_submission == "gearman":
        queue = gearman_queue
        now = time.time()

        # Create gearman job 'payload'
        cmkout = gearman_encode(("type=%s\nhost_name=%s\nstart_time=%.1f\nfinish_time=%.1f\nlatency=%d\nreturn_code=%d\nservice_description=%s\noutput=%s\n" %
                 ("passive", host, now, now, 0.0, state, service, output)))

        # send job to gearman_server
        try:
            gearman_client = gearman.GearmanClient(gearman_server)
            completed_job_request = gearman_client.submit_job(queue, cmkout, background=True, wait_until_complete=False)
        except Exception, e:
            # Cleanup Error output (remove '<', '>') an raise error
            errorout = str(e)
            errorout = (errorout.replace('<', '')).replace('>', '')
            raise MKGeneralException("GEARMAN %s" % errorout)

        # send job to gearman_dup_server
        if gearman_dup_server:
            if gearman_dup_queue:
                queue = gearman_dup_queue
            for s in gearman_dup_server:
                try:
                    gearman_client = gearman.GearmanClient(s)
                    completed_job_request = gearman_client.submit_job(queue, cmkout, background=True, wait_until_complete=False)
                except Exception, e:
                    # Cleanup Error output (remove '<', '>') an raise error
                    errorout = str(e)
                    errorout = (errorout.replace('<', '')).replace('>', '')
                    # If sending to dup servers fails just go on
                    # raise MKGeneralException("GEARMAN %s" % errorout)
                    pass
    else:
        raise MKGeneralException("Invalid setting %r for check_submission. Must be 'pipe', 'file' or 'gearman'" % check_submission)


#   +----------------------------------------------------------------------+
#   |                  _   _      _                                        |
#   |                 | | | | ___| |_ __   ___ _ __ ___                    |
#   |                 | |_| |/ _ \ | '_ \ / _ \ '__/ __|                   |
#   |                 |  _  |  __/ | |_) |  __/ |  \__ \                   |
#   |                 |_| |_|\___|_| .__/ \___|_|  |___/                   |
#   |                              |_|                                     |
#   +----------------------------------------------------------------------+

# determine the name of the current user. This involves
# a lookup of /etc/passwd. Because this function is needed
# only in general error cases, the pwd module is imported
# here - not globally
def username():
    import pwd
    return pwd.getpwuid(os.getuid())[0]

def i_am_root():
    return os.getuid() == 0

# Returns the nodes of a cluster, or None if hostname is
# not a cluster
def nodes_of(hostname):
    for tagged_hostname, nodes in clusters.items():
        if hostname == tagged_hostname.split("|")[0]:
            return nodes
    return None

# (Gearman) Returns AES secret if encryption is on
def gearman_get_secretkey():
    secretkey = None

    # maximum/minimum key string size.
    secretkey_maxsize = 32

    # Read key from gearman_secret or gearman_secret_file. Strip \t,\n,\r and spaces
    # gearman_secret takes precendence
    if gearman_encryption:
        if gearman_secret:
            secretkey = gearman_secret.strip(' \t\n\r')
        elif gearman_secret_file:
            f = open(gearman_secret_file, 'r')
            for key in f.readlines():
                # return the first non-empty line as key
                if not key.isspace():
                    secretkey = key.strip(' \t\n\r')
                    break

        # bring keystring to the right size. If it's too short, fill with \x0; if it's too long, truncate to 32
        try:
            if (len(secretkey) < secretkey_maxsize):
                 mod = secretkey_maxsize - len(secretkey)%secretkey_maxsize
                 for i in range(mod):
                    secretkey = secretkey + chr(0)
            elif (len(secretkey) > secretkey_maxsize):
                secretkey = secretkey[0:secretkey_maxsize]
        except:
            raise MKGeneralException("Encrpytion without key or empty keyfile not possible")

    return secretkey

# (Gearman) Returns encoded string (job payload). If encryption is on, payload will be AES encypted
# else payload is base64 encoded
def gearman_encode(decrypted_string):
    if gearman_encryption:
        aes_secretkey = str(gearman_get_secretkey())
        # pad the text to be encrypted
        aes_blocksize = 16
        aes_padding_char = '{'
        aes_pad = lambda s: s + (aes_blocksize - len(s) % aes_blocksize) * aes_padding_char
        cipher = AES.new(aes_secretkey)
        output = base64.b64encode(cipher.encrypt(aes_pad(decrypted_string)))
    else:
        output = base64.b64encode(decrypted_string)
    return output

#   +----------------------------------------------------------------------+
#   |     ____ _               _      _          _                         |
#   |    / ___| |__   ___  ___| | __ | |__   ___| |_ __   ___ _ __ ___     |
#   |   | |   | '_ \ / _ \/ __| |/ / | '_ \ / _ \ | '_ \ / _ \ '__/ __|    |
#   |   | |___| | | |  __/ (__|   <  | | | |  __/ | |_) |  __/ |  \__ \    |
#   |    \____|_| |_|\___|\___|_|\_\ |_| |_|\___|_| .__/ \___|_|  |___/    |
#   |                                             |_|                      |
#   |                                                                      |
#   | These functions are used in some of the checks.                      |
#   +----------------------------------------------------------------------+


# check range, values might be negative!
# returns True, if value is inside the interval
def within_range(value, minv, maxv):
    if value >= 0: return value >= minv and value <= maxv
    else: return value <= minv and value >= maxv

# compile regex or look it up in already compiled regexes
# (compiling is a CPU consuming process. We cache compiled
# regexes).
def get_regex(pattern):
    reg = compiled_regexes.get(pattern)
    if not reg:
        reg = re.compile(pattern)
        compiled_regexes[pattern] = reg
    return reg

# Names of texts usually output by checks
nagios_state_names = ["OK", "WARN", "CRIT", "UNKNOWN"]

# int() function that return 0 for strings the
# cannot be converted to a number
def saveint(i):
    try:
        return int(i)
    except:
        return 0

def savefloat(f):
    try:
        return float(f)
    except:
        return 0.0

# Takes bytes as integer and returns a string which represents the bytes in a
# more human readable form scaled to GB/MB/KB
# The unit parameter simply changes the returned string, but does not interfere
# with any calcluations
def get_bytes_human_readable(b, base=1024.0, bytefrac=True, unit="B"):
    base = float(base)
    # Handle negative bytes correctly
    prefix = ''
    if b < 0:
        prefix = '-'
        b *= -1

    if b >= base * base * base * base:
        return '%s%.2fT%s' % (prefix, b / base / base / base / base, unit)
    elif b >= base * base * base:
        return '%s%.2fG%s' % (prefix, b / base / base / base, unit)
    elif b >= base * base:
        return '%s%.2fM%s' % (prefix, b / base / base, unit)
    elif b >= base:
        return '%s%.2fk%s' % (prefix, b / base, unit)
    elif bytefrac:
        return '%s%.2f%s' % (prefix, b, unit)
    else: # Omit byte fractions
        return '%s%.0f%s' % (prefix, b, unit)

# Similar to get_bytes_human_readable, but optimized for file
# sizes
def get_filesize_human_readable(size):
    if size < 4 * 1024 * 1024:
        return str(size)
    elif size < 4 * 1024 * 1024 * 1024:
        return "%.2fMB" % (float(size) / (1024 * 1024))
    else:
        return "%.2fGB" % (float(size) / (1024 * 1024 * 1024))


def get_nic_speed_human_readable(speed):
    try:
        speedi = int(speed)
        if speedi == 10000000:
            speed = "10MBit/s"
        elif speedi == 100000000:
            speed = "100MBit/s"
        elif speedi == 1000000000:
            speed = "1GBit/s"
        elif speed < 1500:
            speed = "%dBit/s" % speedi
        elif speed < 1000000:
            speed = "%.1fKBit/s" % (speedi / 1000.0)
        elif speed < 1000000000:
            speed = "%.2fMBit/s" % (speedi / 1000000.0)
        else:
            speed = "%.2fGBit/s" % (speedi / 1000000000.0)
    except:
        pass
    return speed

# Convert Fahrenheit to Celsius
def to_celsius(f):
    return round(float(f) - 32.0) * 5.0 / 9.0

# Format time difference seconds into approximated
# human readable value
def get_age_human_readable(secs):
    if secs < 240:
        return "%d sec" % secs
    mins = secs / 60
    if mins < 120:
        return "%d min" % mins
    hours, mins = divmod(mins, 60)
    if hours < 12:
        return "%d hours, %d min" % (hours, mins)
    if hours < 48:
        return "%d hours" % hours
    days, hours = divmod(hours, 24)
    if days < 7:
        return "%d days, %d hours" % (days, hours)
    return "%d days" % days

# Quote string for use as arguments on the shell
def quote_shell_string(s):
    return "'" + s.replace("'", "'\"'\"'") + "'"


# Check if a timeperiod is currently active. We have no other way than
# doing a Livestatus query. This is not really nice, but if you have a better
# idea, please tell me...
g_inactive_timerperiods = None
def check_timeperiod(timeperiod):
    global g_inactive_timerperiods
    # Let exceptions happen, they will be handled upstream.
    if g_inactive_timerperiods == None:
        import socket
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(livestatus_unix_socket)
        # We just get the currently inactive timeperiods. All others
        # (also non-existing) are considered to be active
        s.send("GET timeperiods\nColumns:name\nFilter: in = 0\n")
        s.shutdown(socket.SHUT_WR)
        g_inactive_timerperiods = s.recv(10000000).splitlines()
    return timeperiod not in g_inactive_timerperiods

