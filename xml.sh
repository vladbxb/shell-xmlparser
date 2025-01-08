#!/bin/sh

last_child=""

reconstruct_xml() {
    local node="$1"
    local indent="$2"

    if echo "$node" | grep -q ":"; then
        local tagname=$(echo "$node" | cut -d: -f1)
    else
        local tagname="$node"
    fi


    local check_for_child="$node:"
    last_child="$tagname"


	local escaped_check_for_child=$(echo "$check_for_child" | sed 's/[][\\]/\\&/g')

    if echo "$graph" | grep -q "^$escaped_check_for_child$"; then
        local node_start=$(echo "$node" | grep -oP '^[^:]*')
        node_start=$(echo "$node_start" | sed 's/ _text="[^"]*"//; s/\[\]//; s/\[/ /; s/\]//')
        local text_content=$(echo "$node" | grep -oP '(?<=_text=")[^"]*(?=")')
        local node_end=$(echo "$node" | sed 's/\[.*//')
        printf "%s<%s>%s</%s>\n" "$indent" "$node_start" "$text_content" "$node_end"
    else
        if echo "$node" | grep -q ":"; then
            local tagname=$(echo "$node" | cut -d: -f1)
        else
            local tagname="$node"
        fi
        tagname=$(echo "$tagname" | sed 's/\[\]//; s/\[/ /; s/\]//')
        printf "%s<%s>\n" "$indent" "$tagname"
	    local escaped_node=$(echo "$node" | sed 's/[][\\]/\\&/g')
        local check_for_children=$(echo "$graph" | grep "^$escaped_node:.*")
        local children=$(echo "$check_for_children" | sed 's/^.*://')
        while echo "$children" | grep -qP '[^\s]+\[.*?\]'; do
            element=$(echo "$children" | grep -oP '[^\s]+\[.*?\]' | head -n1)

            children=$(echo "$children" | sed "s/$(printf '%s' "$element" | sed 's/[][\&\/]/\\&/g')//" | sed 's/^ *//;s/ *$//')

            reconstruct_xml "$element" "    $indent"
        done
        local node_end=$(echo "$node" | sed 's/\[.*//')
        printf "%s</%s>\n" "$indent" "$node_end"
    fi
}

sed 's/^[ \t]*//;s/[ \t]*$//' "$1" | tr -d '\n' | sed -e 's/>/&\n/g' -e 's/</\n&/g' | sed '/^$/d' > "/tmp/xml.tmp"
graph=""
stack=""

while IFS= read -r line; do
	fc=$(echo "$line" | cut -c1)
	sc=$(echo "$line" | cut -c2)

	if [ "$fc" = "<" ]; then
		if [ "$sc" = "/" ]; then
			stack=$(echo "$stack" | sed 's/\(.*\) _.*$/\1/')
		else
			tagname=$(echo "$line" | grep -Po '(?<=<)[^ >/]+')
			attributes=$(echo "$line" | grep -Po '(?<= )[^\n>]+')
			element="$tagname[$attributes]"

			if [ -z "$graph" ]; then
				graph="$element:"
			elif [ -n "$stack" ]; then
				parent=$(echo "$stack" | sed 's/.*_//')
				if [ -z "$parent" ]; then
					break
				else
					escaped_parent=$(echo "$parent" | sed 's/[][\\]/\\&/g')
					escaped_element=$(echo "$element" | sed 's/[][\\]/\\&/g')
					graph=$(echo "$graph" | sed "s/^$escaped_parent:.*/& $escaped_element/")
					graph=$(echo "$graph"; echo "$element:")
				fi
			else
				graph=$(echo "$graph"; echo "$element:")
			fi


			if [ -z "$stack" ]; then
				stack="$stack _$element"
			else
				stack="$stack _$element"
			fi
		fi
	else
		text=" _text=\"$line\""
		escaped_text=$(echo "$text" | sed 's/[][\\]/\\&/g')
		graph=$(echo "$graph" | sed "/$escaped_element/ s/\[\(.*\)\]/[\1$escaped_text]/")
	fi
done < "/tmp/xml.tmp"

echo "$graph"
printf "\n"

graph_numbered=$(echo "$graph" | nl -s ":" -n ln -w 1)
line_number="1"

while echo "$graph_numbered" | grep -q "^$line_number"; do
    last_child=""
    root_child=$(echo "$graph_numbered" | grep "^$line_number" | cut -d: -f2)
    reconstruct_xml "$root_child" ""
	escaped_last_child=$(echo "$last_child" | sed 's/[][\\]/\\&/g')
    line_number=$(echo "$graph_numbered" | grep "$escaped_last_child:$" | cut -d: -f1)
    temp=$(($line_number + 1))
    line_number="$temp"
done


