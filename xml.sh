#!/bin/sh
#sed 's/^[ \t]*//;s/[ \t]*$//' "$1" | sed 's/^/ /' | tr -d '\n' | sed -e 's/>/&\n/g' -e 's/</\n&/g' | sed '/^$/d' > "/tmp/xml.tmp"

last_child=""

reconstruct_xml() {
    local node="$1"
    local indent="$2"

    if echo "$node" | grep -q ":"; then
        local tagname=$(echo "$node" | cut -d: -f1)
    else
        local tagname="$node"
    fi

    #printf "tagname: %s\n" "$tagname"

    local check_for_child="$node:"
    #printf "%s\n" "$check_for_child"
    last_child="$tagname"

    #printf "%s\n" "$graph"

    #printf "node: %s\n" "$node"
	local escaped_check_for_child=$(echo "$check_for_child" | sed 's/[][\\]/\\&/g')

    if echo "$graph" | grep -q "^$escaped_check_for_child$"; then
        local node_start=$(echo "$node" | grep -oP '^[^:]*')
        node_start=$(echo "$node_start" | sed 's/ _text="[^"]*"//; s/\[\]//; s/\[/ /; s/\]//')
        local text_content=$(echo "$node" | grep -oP '(?<=_text=")[^"]*(?=")')
        local node_end=$(echo "$node" | sed 's/\[.*//')
        # Print the opening tag
        printf "%s<%s>%s</%s>\n" "$indent" "$node_start" "$text_content" "$node_end"
        #echo -e "$indent<$node_start>$text_content</$node_end>\n"
    else
        #printf "am ajuns aici\n"
        if echo "$node" | grep -q ":"; then
            local tagname=$(echo "$node" | cut -d: -f1)
        else
            local tagname="$node"
        fi
        tagname=$(echo "$tagname" | sed 's/\[\]//; s/\[/ /; s/\]//')
        printf "%s<%s>\n" "$indent" "$tagname"
        #echo -e "$indent<$tagname>\n"
        # Get the children of the current node
        #local children=$(echo "$graph" | grep "^$node" | cut -d: -f2-)
        #local children=$(echo "$node" | grep -P '(?<=: )[^\s]+\[[^\]]*\]')
        #children=$(echo "$node" | grep -oP '(?<=: )[^\s]+\[[^\]]*\](?:\s+[^\s]+\[[^\]]*\])*' | tr ' ' '\n')
        #children=$(echo "$node" | grep -oP '[^\s:]+\[.*?\]')
        #children=$(echo "$children" | sed 's/ /\n/g')
        #printf "node: %s\n" "$node"
	    local escaped_node=$(echo "$node" | sed 's/[][\\]/\\&/g')
        local check_for_children=$(echo "$graph" | grep "^$escaped_node:.*")
        #local children=$(echo "$check_for_children" | sed 's/^.*://' | sed 's/\] /\]\n/g' )
        local children=$(echo "$check_for_children" | sed 's/^.*://')
        #printf "children: %s\n" "$children"
        #printf "am dat check la children\n"
        #echo -e "$children\n"

        # Traverse each child
        #for child in $children; do
        #    reconstruct_xml "$child" "  $indent"
        #done

        #echo "$children" | while IFS= read -r child; do
        #    reconstruct_xml "$child" "    $indent"
        #done;
        while echo "$children" | grep -qP '[^\s]+\[.*?\]'; do
        #echo "$children" | while IFS= read -r child; do
            # Extract the first match
            element=$(echo "$children" | grep -oP '[^\s]+\[.*?\]' | head -n1)
            #printf "element: %s\n" "$element"

            # Remove the matched element from the input string
            children=$(echo "$children" | sed "s/$(printf '%s' "$element" | sed 's/[][\&\/]/\\&/g')//" | sed 's/^ *//;s/ *$//')

            # Process the element
            #printf "Processing: %s\n" "$element"

            reconstruct_xml "$element" "    $indent"

            # Extract child name and properties
            #child_name=$(echo "$element" | grep -oP '^[^\[]+')
            #properties=$(echo "$element" | grep -oP '\[.*?\]' | sed 's/^\[//;s/\]$//')

            #echo "Child: $child_name"
            #echo "Properties: $properties"
        done
        local node_end=$(echo "$node" | sed 's/\[.*//')
        # Print the closing tag
        printf "%s</%s>\n" "$indent" "$node_end"
    fi
}

#main

sed 's/^[ \t]*//;s/[ \t]*$//' "$1" | tr -d '\n' | sed -e 's/>/&\n/g' -e 's/</\n&/g' | sed '/^$/d' | sed ':a; /<!--/,/-->/ { /-->/!{N;ba}; s/<!--.*?-->//g }' > "/tmp/xml.tmp"
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
					#graph=$(echo "$graph" | sed "s/^$parent:.*/& $element/")
					graph=$(echo "$graph" | sed "s/^$escaped_parent:.*/& $escaped_element/")
					#graph=$(echo "$graph" | sed "s/^$escaped_parent:\(.*\)/$escaped_parent:\1 $escaped_element/")	
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

#echo -e "$graph_numbered\n\n"

# test_var='pula[grosime="enorma" _text="tare si mare"]:'
# 
# escaped_node=$(echo "$test_var" | sed 's/[][\\]/\\&/g')
# 
# echo "$graph" | grep "$escaped_node"

line_number="1"
# root_child=$(echo "$graph_numbered" | grep "^$line_number" | cut -d: -f2)
# printf "root_child: %s\n" "$root_child"
# reconstruct_xml "$root_child" ""

while echo "$graph_numbered" | grep -q "^$line_number"; do
    last_child=""
    root_child=$(echo "$graph_numbered" | grep "^$line_number" | cut -d: -f2)
    reconstruct_xml "$root_child" ""
    #printf "last_child: %s\n" "$last_child"
	escaped_last_child=$(echo "$last_child" | sed 's/[][\\]/\\&/g')
    line_number=$(echo "$graph_numbered" | grep "$escaped_last_child:$" | cut -d: -f1)
    temp=$(($line_number + 1))
    line_number="$temp"
done


# Recursive function to traverse the graph and reconstruct the XML

# echo "$graph" | tac > "/tmp/xml_reversed.tmp"
# 
# echo "" > "/tmp/xml_reconstructed.tmp"
# 
# cat "/tmp/xml_reversed.tmp" | grep -P ":$" > "/tmp/xml_test.tmp"
# 
# while IFS= read -r line; do
# 	if echo "$line" | grep -Pq ":$"; then
# 		tagname=$(echo "$line" | grep -Po '^[^[]*(?=\[)')
# 		attributes=$(echo "$line" | grep -Po '(?<=\[)[^]]*(?= _)')
# 		text=$(echo "$line" | grep -Po '(?<=_text=")[^"]*(?=")')
# 		if [ -n "$attributes" ]; then
# 			echo "<$tagname $attributes>$text</$tagname>" | cat - "/tmp/xml_reconstructed.tmp" > "/tmp/xml_temporary.tmp" && mv "/tmp/xml_temporary.tmp" "/tmp/xml_reconstructed.tmp"
# 		else
# 			echo "<$tagname>$text</$tagname>" | cat - "/tmp/xml_reconstructed.tmp" > "/tmp/xml_temporary.tmp" && mv "/tmp/xml_temporary.tmp" "/tmp/xml_reconstructed.tmp"
# 		fi
# 	else
# 		children=$(echo "$line" | grep -Po '(?<=:).*')
# 		tagname=$(echo "$line" | grep -Po '^[^[]*(?=\[)')
# 		attributes=$(echo "$line" | grep -Po '(?<=\[)[^]]*(?= _)')
# 		children=$(echo "$children" | sed 's/\([^[ ]*\[[^]]*\]\)/\1\n/g' | sed 's/^[ \t]*//;s/[ \t]*$//')
# 		firstChild=$(echo "$children" | head -n 1 | grep -Po '^[^[]*(?=\[)')
# 		lastChild=$(echo "$children" | tail -n 1 | grep -Po '^[^[]*(?=\[)')
# 		firstChildLineNumber=$(grep -n "$firstChild" "/tmp/xml_reconstructed.tmp" | cut -d: -f1 )
# 		lastChildLineNumber=$(grep -n "$lastChild" "/tmp/xml_reconstructed.tmp" | cut -d: -f1)
# 		temp=$((lastChildLineNumber + 1))
# 		lastChildLineNumber="$temp"
# 		#echo "$firstChildLineNumber $lastChildLineNumber"
# 		#echo "$firstChild $lastChild"
# 		#firstChildLine_escaped=$(echo "$firstChildLine" | sed 's/[][\\]/\\&/g')
# 		#lastChildLine_escaped=$(echo "$lastChildLine" | sed 's/[][\\]/\\&/g')
# 		attributes_escaped=$(echo "$attributes" | sed 's/"/\\"/g')
# 		#echo "$attributes_escaped"
# 
# 		if [ -n "$attributes_escaped" ]; then
# 			sed -e "${firstChildLineNumber} i\\<$tagname $attributes_escaped>" /tmp/xml_reconstructed.tmp > /tmp/xml_temporary.tmp && mv /tmp/xml_temporary.tmp /tmp/xml_reconstructed.tmp
# 			sed -e "${lastChildLineNumber} a\\</$tagname>" /tmp/xml_reconstructed.tmp > /tmp/xml_temporary.tmp && mv /tmp/xml_temporary.tmp /tmp/xml_reconstructed.tmp
# 		else
# 			sed "$firstChildLineNumber i\\<$tagname>" /tmp/xml_reconstructed.tmp > /tmp/xml_temporary.tmp && mv /tmp/xml_temporary.tmp /tmp/xml_reconstructed.tmp
# 			sed "$lastChildLineNumber a\\</$tagname>" /tmp/xml_reconstructed.tmp > /tmp/xml_temporary.tmp && mv /tmp/xml_temporary.tmp /tmp/xml_reconstructed.tmp
# 		fi
# 	fi
# 
# done < "/tmp/xml_reversed.tmp"
# 
# cat "/tmp/xml_reconstructed.tmp"
