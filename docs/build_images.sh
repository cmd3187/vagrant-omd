find . -name *.dot -type f -exec echo "dot -Tpng {} > {}.png" \; | bash
