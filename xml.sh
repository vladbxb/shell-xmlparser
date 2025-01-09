#!/bin/sh

last_child=""

file_checker()
{
FILE="$1"

# Check if the file exists
if [ ! -e "$FILE" ]; then
    echo "Error: Fisierul nu exista"
    exit
fi

# Check if the path is a file (not a directory or other type)
if [ ! -f "$FILE" ]; then
    echo "Error: Path-ul nu e un fisier valid."
    exit
fi

# Check if the file has read permissions
if [ ! -r "$FILE" ]; then
    echo "Error: Fisierul nu poate fi citit."
    exit
fi

# Check if the file is not empty
if [ ! -s "$FILE" ]; then
    echo "Error: Fisierul este gol."
    exit
fi
}

add_property() {
    # $1 - elementul in care sa adauge
    # $2 - proprietatea pe care sa o adauge ( proprietate + atribut (daca exista) )
    local element="$1"
	local escaped_element=$(echo "$element" | sed 's/[][\\]/\\&/g')
    local property="$2"
    local property_trimmed=$(echo "$property" | sed 's/^[ \t]*//')
    local escaped_property=$(echo "$property" | sed 's/[\\&"]/\\&/g')
    graph=$(echo "$graph" | sed "/$escaped_element/ s/\[\(.*\)\]/[\1 $escaped_property]/")
}

add_child() {
    # $1 - tatal la care sa adauge
    # $2 - copilul pe care sa-l adauge
    local parent="$1"
    local element="$2"
    local escaped_parent=$(echo "$parent" | sed 's/[][\\]/\\&/g')
    local escaped_element=$(echo "$element" | sed 's/[][\\]/\\&/g')
    graph=$(echo "$graph" | sed "s/^$escaped_parent:.*/& $escaped_element/")
    graph=$(echo "$graph"; echo "$element:")
}


remove_metatags() {
    # $1 - elementul caruia ii stergem proprietatile ilegale
    #cleaned_element=$(echo "$1" | sed 's/_[^ =]*\(\(="[^"]*"\)\?\)[ \t]*//g' | sed 's/[ \t]*$//')
    #cleaned_element=$(echo "$1" | sed 's/_[^ =]*\(\(="[^"]*"\)\?\)[ \t]*//g' | sed 's/^[ \t]*//;s/[ \t]*$//')
    #cleaned_element=$(echo "$1" | sed 's/_[^ =]*\(\(="[^"]*"\)\?\)[ \t]*//g' | sed 's/^[ \t]*//;s/[ \t]*$//')
    cleaned_element="$1"
    if echo "$1" | grep -q '\[[^]]*_self[^]]*\]'; then
        cleaned_element=$(echo "$cleaned_element" | sed 's/_self//g')
    fi
    if echo "$1" | grep -q '\[[^]]*_question[^]]*\]'; then
        cleaned_element=$(echo "$cleaned_element" | sed 's/_question//g')
    fi
    cleaned_element=$(echo "$cleaned_element" | sed -E 's/_text=".*"/_text=""/g')
    cleaned_element=$(echo "$cleaned_element" | sed 's/ _[^ =]*\(\(="[^"]*"\)\?\)[ \t]*//g;s/\[ *\]/\[\]/g; s/_[^ =]*\(\(="[^"]*"\)\?\)[ \t]*//g;s/\[ *\]/\[\]/g')


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
        elif echo "$node_start" | grep -q '\[[^]]*_question[^]]*\]'; then
            echo "$node_start"
            node_start=$(remove_metatags "$node_start" | sed 's/\[\]//; s/\[/ /; s/\]//')
            printf "%s<?%s?>\n" "$indent" "$node_start"
        else
            node_start=$(remove_metatags "$node_start" | sed 's/\[\]//; s/\[/ /; s/\]//')
            local text_content=$(echo "$node" | grep -o '_text=".*"' | sed -E 's/_text="(.*)"/\1/')
            text_content=$(echo "$text_content" | sed 's/\\&/\&amp;/g; s/\\</\&lt;/g; s/\\>/\&gt;/g; s/\\"/\&quot;/g; s/\\'\''/\&apos;/g')
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
	#normalized_data=$(sed 's/^[ \t]*//;s/[ \t]*$//' "$1" | tr '\n' ' ' | sed 's/>[ ]*</></g' | sed -e 's/>/&\n/g' -e 's/>/\n&/g' -e 's/</\n&/g' -e 's/</&\n/g' | sed '/^$/d')
	#normalized_data=$(sed 's/^[ \t]*//;s/[ \t]*$//' "$1" | tr '\n' ' ' | sed 's/>[ ]*</></g'| sed 's/<!--[^>]*-->//g' | sed -e 's/>/&\n/g' -e 's/>/\n&/g' -e 's/</\n&/g' -e 's/</&\n/g' | sed '/^$/d')
    normalized_data=$(sed 's/^[ \t]*//;s/[ \t]*$//' "$1" | tr '\n' ' ' | sed 's/>[ ]*</></g'| sed 's/<!--[^>]*-->//g' | sed -e 's/>/&\n/g' -e 's/>/\n&/g' -e 's/</\n&/g' -e 's/</&\n/g' | sed '/^$/d')
    echo "$normalized_data"

}




input_file="$1"

file_checker "$input_file"

pre_process "$input_file" > /tmp/pre_processed_xml.tmp


graph=""
stack=""

serial="1"

while IFS= read -r line; do
    fc=$(echo "$line" | cut -c1)
    lc=$(echo "$line" | rev | cut -c1)
    if [ "$fc" = "<" ]; then
        tag_open="true"
        element_open="true"
    elif [ "$fc" = ">" ]; then
        tag_open="false"
    elif [ "$tag_open" = "true" ]; then # procesam numele tagului si atributele
        if [ "$fc" = "/" ]; then
            stack=$(echo "$stack" | sed 's/\(.*\) @.*$/\1/')
            element_open="false"
        else
            #if [ "$fc" = "?" ]; then
            #    is_processing="true"
            #else
                tagname=$(echo "$line" | sed 's/^\([^ \t]*\).*/\1/')
                attributes=$(echo "$line" | sed "s/$tagname//" | sed 's/[ \t]*$//')
                if [ "$lc" = "/" ]; then
                    attributes=$(echo "$attributes" | sed 's/\/$//')
                    element="$tagname[_$serial _self $attributes]"
                elif [ "$lc" = "?" ]; then
                    tagname=$(echo "$tagname" | sed 's/^?//')
                    attributes=$(echo "$attributes" | sed 's/?$//')
                    element="$tagname[_$serial _question $attributes]"
                else
                    element="$tagname[_$serial $attributes]"
                fi
                temp=$(($serial + 1))
                serial="$temp"
                if [ -z "$graph" ]; then
                    graph="$element:"
                elif [ -n "$stack" ]; then
                    parent=$(echo "$stack" | sed 's/.*@//')
                    if [ -z "$parent" ]; then
                        break
                    else
                        add_child "$parent" "$element"
                    fi
                else
                    graph=$(echo "$graph"; echo "$element:")
                fi
                if [ "$lc" != "/" ] && [ "$lc" != "?" ]; then
                    stack="$stack @$element"
                fi
            fi
    elif [ "$element_open" = "true" ] && [ "$tag_open" = "false" ]; then
         text="_text=\"$line\""
         text=$(echo "$text" | sed -e 's/&amp;/\\\&/g' -e 's/&lt;/\\</g' -e 's/&gt;/\\>/g' -e 's/&quot;/\\\"/g' -e "s/&apos;/\\\'/g")
         #escaped_text=$(echo "$text" | sed 's/[][\\]/\\&/g')
         add_property "$element" "$text"
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