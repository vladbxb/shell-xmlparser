#!/bin/sh

last_child=""

add_property() {
    # $1 - elementul in care sa adauge
    # $2 - proprietatea pe care sa o adauge ( proprietate + atribut (daca exista) )
    # $3 - variabila graf
    local element="$1"
	local escaped_element=$(echo "$element" | sed 's/[][\\]/\\&/g')
    local property="$2"
    local property_trimmed=$(echo "$property" | sed 's/^[ \t]*//')
    local escaped_property=$(echo "$property" | sed 's/[][\\]/\\&/g')
    graph=$(echo "$graph" | sed "/$escaped_element/ s/\[\(.*\)\]/[\1 $escaped_property]/")
}

remove_metatags() {
    # $1 - elementul caruia ii stergem proprietatile ilegale
    #cleaned_element=$(echo "$1" | sed 's/_[^ =]*\(\(="[^"]*"\)\?\)[ \t]*//g' | sed 's/[ \t]*$//')
    #cleaned_element=$(echo "$1" | sed 's/_[^ =]*\(\(="[^"]*"\)\?\)[ \t]*//g' | sed 's/^[ \t]*//;s/[ \t]*$//')
    #cleaned_element=$(echo "$1" | sed 's/_[^ =]*\(\(="[^"]*"\)\?\)[ \t]*//g' | sed 's/^[ \t]*//;s/[ \t]*$//')
    cleaned_element=$(echo "$1" | sed 's/_[^ =]*\(\(="[^"]*"\)\?\)[ \t]*//g;s/\[ *\]/\[\]/g')
    echo "$cleaned_element"
}

    

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
        #node_start=$(echo "$node_start" | sed 's/ _text="[^"]*"//; s/\[\]//; s/\[/ /; s/\]//')
        if echo "$node_start" | grep -q '\[[^]]*_self[^]]*\]'; then
            node_start=$(remove_metatags "$node_start" | sed 's/\[\]//; s/\[/ /; s/\]//')
            printf "%s<%s/>\n" "$indent" "$node_start"
        else
            node_start=$(remove_metatags "$node_start" | sed 's/\[\]//; s/\[/ /; s/\]//')
            local text_content=$(echo "$node" | grep -oP '(?<=_text=")[^"]*(?=")')
            local node_end=$(echo "$node" | sed 's/\[.*//')
            printf "%s<%s>%s</%s>\n" "$indent" "$node_start" "$text_content" "$node_end"
        fi
    else
        if echo "$node" | grep -q ":"; then
            local tagname=$(echo "$node" | cut -d: -f1)
        else
            local tagname="$node"
        fi
        tagname=$(remove_metatags "$tagname" | sed 's/\[\]//; s/\[/ /; s/\]//')
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

pre_process() {
    normalized_data=$(sed 's/^[ \t]*//;s/[ \t]*$//' "$1" | tr -d '\n' | sed -e 's/>/&\n/g' -e 's/</\n&/g' | sed '/^$/d')
    echo "$normalized_data"
}




input_file="$1"

pre_process "$input_file" > /tmp/pre_processed_xml.tmp

#echo "normalized_xml $normalized_xml"

graph=""
stack=""

serial="1"

    # $1 - xml char stream
    # local graph=""
    # local serial="1"
    # local stack=""
    # local fc=""
    # local sc=""
    # local tagname=""
    # local attributes=""
    # local element=""
    # local temp=""
    # local text=""
    # local parent=""
    # local escaped_parent=""
    # local escaped_element=""
    # local line=""
    while IFS= read -r line; do
        fc=$(echo "$line" | cut -c1)
        sc=$(echo "$line" | cut -c2)
        if [ "$fc" = "<" ]; then
            if [ "$sc" = "/" ]; then
                #stack=$(echo "$stack" | sed 's/\(.*\) _.*$/\1/')
                stack=$(echo "$stack" | sed 's/\(.*\) @.*$/\1/')
            else
                lsc=$(echo "$line" | rev | cut -c2)
                tagname=$(echo "$line" | grep -Po '(?<=<)[^ >/]+')
                attributes=$(echo "$line" | grep -Po '(?<= )[^\n>]+')
                if [ "$lsc" = "/" ]; then
                    element="$tagname[_$serial _self $attributes]"
                else
                    element="$tagname[_$serial $attributes]"
                fi
                temp=$(($serial + 1))
                serial="$temp"
                if [ -z "$graph" ]; then
                    graph="$element:"
                elif [ -n "$stack" ]; then
                    #parent=$(echo "$stack" | sed 's/.*_//')
                    parent=$(echo "$stack" | sed 's/.*@//')
                    #echo "parent is $parent"
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


                #stack="$stack _$element"
                if [ "$lsc" != "/" ]; then
                    stack="$stack @$element"
                fi
                #echo "stack is $stack"
            fi
        else
            text="_text=\"$line\""
            #escaped_text=$(echo "$text" | sed 's/[][\\]/\\&/g')
            add_property "$element" "$text" "$graph"
            #graph=$(echo "$graph" | sed "/$escaped_element/ s/\[\(.*\)\]/[\1$escaped_text]/")
        fi
    done < "/tmp/pre_processed_xml.tmp"

printf "%s\n" "$graph"

graph_numbered=$(echo "$graph" | nl -s ":" -n ln -w 1)
line_number="1"

while echo "$graph_numbered" | grep -q "^$line_number"; do
    last_child=""
    root_child=$(echo "$graph_numbered" | grep "^$line_number:" | cut -d: -f2)
    reconstruct_xml "$root_child" ""
	escaped_last_child=$(echo "$last_child" | sed 's/[][\\]/\\&/g')
    line_number=$(echo "$graph_numbered" | grep "$escaped_last_child:$" | cut -d: -f1)
    temp=$(($line_number + 1))
    line_number="$temp"
done


