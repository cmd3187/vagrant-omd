require "puppet"

module Puppet
	Puppet::Type.newtype(:omd_site) do
		@doc = "A Open Monitoring Distribution Site"
		
		newparam(:sitename) do
			isnamevar
			desc "Name of the new site"
		end

		newparam(:core) do
			desc "Core to monitor with. Must be icinga, nagios or shirken"
		end
	end
end
