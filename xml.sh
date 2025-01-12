#!/bin/sh

last_child=""

file_checker()
{
    FILE="$1"

    if [ ! -e "$FILE" ]; then
        echo "Error: File not found." > /dev/tty
        exit 1
    fi

    if [ ! -f "$FILE" ]; then
        echo "Error: Path is not a file." > /dev/tty
        exit 1
    fi

    if [ ! -r "$FILE" ]; then
        echo "Error: File can't be read." > /dev/tty
        exit 1
    fi

    if [ ! -s "$FILE" ]; then
        echo "Error: File is empty." > /dev/tty
        exit 1
    fi
}

add_property() {
    # $1 - elementul in care sa adauge
    # $2 - proprietatea pe care sa o adauge ( proprietate + atribut (daca exista) )
    # local element="$1"
	# local escaped_element=$(echo "$element" | sed 's/[][\\]/\\&/g')
    # local property="$2"
    # local property_trimmed=$(echo "$property" | sed 's/^[ \t]*//')
    # local escaped_property=$(echo "$property" | sed 's/[\\&"]/\\&/g')
    #
    element="$1"
	escaped_element=$(echo "$element" | sed 's/[][\\]/\\&/g')
    property="$2"
    property_trimmed=$(echo "$property" | sed 's/^[ \t]*//')
    escaped_property=$(echo "$property_trimmed" | sed 's/[\\&"]/\\&/g')
    graph=$(echo "$graph" | sed "/$escaped_element/ s/\[\(.*\)\]/[\1 $escaped_property]/")
}

add_child() {
    # $1 - tatal la care sa adauge
    # $2 - copilul pe care sa-l adauge
    # local parent="$1"
    # local element="$2"
    # local escaped_parent=$(echo "$parent" | sed 's/[][\\]/\\&/g')
    # local escaped_element=$(echo "$element" | sed 's/[][\\]/\\&/g')

    parent="$1"
    element="$2"
    escaped_parent=$(echo "$parent" | sed 's/[][\\]/\\&/g')
    escaped_element=$(echo "$element" | sed 's/[][\\]/\\&/g')
    graph=$(echo "$graph" | sed "s/^$escaped_parent:.*/& $escaped_element/")
    graph=$(echo "$graph"; echo "$element:")
}


remove_metatags() {
    # $1 - elementul caruia ii stergem proprietatile ilegale
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
    # local node="$1"
    if [ "$called_by_build" = "true" ] && [ -z "$output_file" ]; then
        if [ "$quiet" = "false" ]; then
            echo -n "." > /dev/tty
        fi
    fi

    node="$1"

    if echo "$node" | grep -q ":"; then
        # local tagname=$(echo "$node" | cut -d: -f1)
        tagname=$(echo "$node" | cut -d: -f1)
    else
        # local tagname="$node"
        tagname="$node"
    fi


    # local check_for_child="$node:"
    check_for_child="$node:"
    last_child="$tagname"


	# local escaped_check_for_child=$(echo "$check_for_child" | sed 's/[][\\]/\\&/g')
	escaped_check_for_child=$(echo "$check_for_child" | sed 's/[][\\]/\\&/g')

    if echo "$graph" | grep -q "^$escaped_check_for_child$"; then
        # local node_start=$(echo "$node" | grep -oP '^[^:]*')
        node_start=$(echo "$node" | grep -oP '^[^:]*')
        if echo "$node_start" | grep -q '\[[^]]*_self[^]]*\]'; then
            node_start=$(remove_metatags "$node_start" | sed 's/\[\]//; s/\[/ /; s/\]//')
            printf "<%s/>\n" "$node_start"
        elif echo "$node_start" | grep -q '\[[^]]*_question[^]]*\]'; then
            node_start=$(remove_metatags "$node_start" | sed 's/\[\]//; s/\[/ /; s/\]//')
            printf "<?%s?>\n" "$node_start"
        else
            node_start=$(remove_metatags "$node_start" | sed 's/\[\]//; s/\[/ /; s/\]//')
            # local text_content=$(echo "$node" | grep -o '_text=".*"' | sed -E 's/_text="(.*)"/\1/')
            text_content=$(echo "$node" | grep -o '_text=".*"' | sed -E 's/_text="(.*)"/\1/')
            text_content=$(echo "$text_content" | sed 's/\\&/\&amp;/g; s/\\</\&lt;/g; s/\\>/\&gt;/g; s/\\"/\&quot;/g; s/\\'\''/\&apos;/g')
            # local node_end=$(echo "$node" | sed 's/\[.*//')
            node_end=$(echo "$node" | sed 's/\[.*//')
            #indent=$(echo "$indent_stack" | sed 's/.*@//')
            printf "<%s>%s</%s>\n" "$node_start" "$text_content" "$node_end"
        fi
    else
        if echo "$node" | grep -q ":"; then
            # local tagname=$(echo "$node" | cut -d: -f1)
            tagname=$(echo "$node" | cut -d: -f1)
        else
            # local tagname="$node"
            tagname="$node"
        fi
        func_stack="$func_stack @$node"
        #indent_stack="$indent_stack @$indent"
        tagname=$(remove_metatags "$tagname" | sed 's/\[\]//; s/\[/ /; s/\]//')
        printf "<%s>\n" "$tagname"
	    # local escaped_node=$(echo "$node" | sed 's/[][\\]/\\&/g')
        # local check_for_children=$(echo "$graph" | grep "^$escaped_node:.*")
        # local children=$(echo "$check_for_children" | sed 's/^.*://')
	    escaped_node=$(echo "$node" | sed 's/[][\\]/\\&/g')
        check_for_children=$(echo "$graph" | grep "^$escaped_node:.*")
        children=$(echo "$check_for_children" | sed 's/^.*://')
        while echo "$children" | grep -qP '[^\s]+\[.*?\]'; do
            element=$(echo "$children" | grep -oP '[^\s]+\[.*?\]' | head -n1)
            element_stack="$element_stack @$element"
            children_stack="$children_stack @$children"
            #echo "children_stack: $children_stack" > /dev/tty


            reconstruct_xml "$element"
            children=$(echo "$children_stack" | sed 's/.* @//')
            children_stack=$(echo "$children_stack" | sed 's/\(.*\) @.*$/\1/')
            #echo "children_stack after pop: $children_stack" > /dev/tty
            element=$(echo "$element_stack" | sed 's/.*@//')
            element_stack=$(echo "$element_stack" | sed 's/\(.*\) @.*$/\1/')
            children=$(echo "$children" | sed "s/$(printf '%s' "$element" | sed 's/[][\&\/]/\\&/g')//" | sed 's/^ *//;s/ *$//')
        done
        # local node_end=$(echo "$node" | sed 's/\[.*//')
        node=$(echo "$func_stack" | sed 's/.*@//')
        # indent=$(echo "$indent_stack" | sed 's/.*@//')
        # indent_stack=$(echo "$indent_stack" | sed 's/\(.*\) @.*$/\1/')
        func_stack=$(echo "$func_stack" | sed 's/\(.*\) @.*$/\1/')
        node_end=$(echo "$node" | sed 's/\[.*//')
        printf "</%s>\n" "$node_end"
    fi
}

pre_process() {
    normalized_data=$(sed 's/^[ \t]*//;s/[ \t]*$//' "$1" | tr '\n' ' ' | sed 's/>[ ]*</></g'| sed 's/<!--[^>]*-->//g' | sed -e 's/>/&\n/g' -e 's/>/\n&/g' -e 's/</\n&/g' -e 's/</&\n/g' | sed '/^$/d')
    echo "$normalized_data"

}

parse_xml() {

    file_checker "$input_file"

    if [ "$?" = "1" ]; then
        exit
    fi

    echo "" > /tmp/pre_processed_xml.tmp

    if [ "$quiet" = "false" ]; then
        echo "" > /dev/tty
        echo -n "Parsing" > /dev/tty
    fi

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
                        element="${tagname}[_$serial _self $attributes]"
                    elif [ "$lc" = "?" ]; then
                        tagname=$(echo "$tagname" | sed 's/^?//')
                        attributes=$(echo "$attributes" | sed 's/?$//')
                        element="${tagname}[_$serial _question $attributes]"
                    else
                        element="${tagname}[_$serial $attributes]"
                    fi
                    temp=$((serial + 1))
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
        if [ "$quiet" = "false" ]; then
            echo -n "."
        fi
    done < "/tmp/pre_processed_xml.tmp"
    if [ "$quiet" = "false" ]; then
        echo "" > /dev/tty
        echo "Done!" > /dev/tty
        echo "" > /dev/tty
        echo "" > /dev/tty
    fi
}

indent_xml_file() {
    file_to_indent="$1"
    depth=0

    # Read the XML file line by line
    while IFS= read -r line || [ -n "$line" ]; do
        if [ "$called_by_build" = "true" ] && [ -z "$output_file" ]; then
            if [ "$quiet" = "false" ]; then
                echo -n "." > /dev/tty
            fi
        fi
        trimmed_line=$(echo "$line" | sed 's/^[ \t]*//;s/[ \t]*$//')

        [ -z "$trimmed_line" ] && continue

        if echo "$trimmed_line" | grep -q '^</'; then
            depth=$((depth - 1))
        fi

        printf "%s%s\n" "$(printf ' %.0s' $(seq 1 $((depth * 4))))" "$trimmed_line" | sed 's/^ //'

        if echo "$trimmed_line" | grep -q '^<[^/!?][^>]*[^/]>$'; then
            depth=$((depth + 1))
        fi
    done < "$file_to_indent"

}

build() {
    echo "" > /tmp/reconstructed_xml.tmp
    if [ "$quiet" = "false" ]; then
        echo "" > /dev/tty
        echo -n "Rebuilding graph" > /dev/tty
    fi
    graph_numbered=$(echo "$graph" | nl -s ":" -n ln -w 1)
    line_number="1"

    func_stack=""
    indent_stack=""
    children_stack=""

    while echo "$graph_numbered" | grep -q "^$line_number"; do
        last_child=""
        root_child=$(echo "$graph_numbered" | grep "^$line_number:" | cut -d: -f2)
        called_by_build="true"
        reconstruct_xml "$root_child" >> /tmp/reconstructed_xml.tmp
        escaped_last_child=$(echo "$last_child" | sed 's/[][\\]/\\&/g')
        line_number=$(echo "$graph_numbered" | grep "$escaped_last_child:$" | cut -d: -f1)
        temp=$((line_number + 1))
        line_number="$temp"
    done

    indent_xml_file "/tmp/reconstructed_xml.tmp" > /tmp/indented_xml.tmp

    if [ "$quiet" = "false" ]; then
        echo "" > /dev/tty
        echo "Done!" > /dev/tty
        echo "" > /dev/tty
        echo "" > /dev/tty
    fi
    cat /tmp/indented_xml.tmp
}

show_ascii_art() {

echo "__   _____  ___ _     ______                        " > /dev/tty
echo "\ \ / /|  \/  || |    | ___ \                       " > /dev/tty
echo " \ V / | .  . || |    | |_/ /_ _ _ __ ___  ___ _ __ " > /dev/tty
echo " /   \ | |\/| || |    |  __/ _\` | '__/ __|/ _ \ '__|" > /dev/tty
echo "/ /^\ \| |  | || |____| | | (_| | |  \__ \  __/ |   " > /dev/tty
echo "\/   \/\_|  |_/\_____/\_|  \__,_|_|  |___/\___|_|   " > /dev/tty
echo "                                                    " > /dev/tty
echo "                                                    " > /dev/tty

}


usage() {
    echo "Usage: $0 [-q] [-h] [-g] [-o output_file] [xml_file1] [xml_file2] ... [xml_fileN]" > /dev/tty
    echo "  -q                Prints only necessary output to console (quiet mode)" > /dev/tty
    echo "  -h                Show this help message" > /dev/tty
    echo "  -g                Show adjacency list" > /dev/tty
    echo "  -o output_file    Choose an output file for the rebuilt XML file" > /dev/tty
}

input_file=""
output_file=""
quiet="false"
help_shown="false"
show_graph="false"
called_by_build="false"

while getopts ":qhgo:" opt; do
    case "$opt" in
        q)
            quiet="true"
            ;;
        h)
            help_shown="true"
            show_ascii_art
            usage
            ;;
        g)
            show_graph="true"
            ;;
        o)
            output_file="$OPTARG"
            ;;
        :)
            echo "Error: Option -$OPTARG requires an argument." > /dev/tty
            usage
            exit 1
            ;;
        ?)
            echo "Error: Invalid option -$OPTARG" > /dev/tty
            usage
            exit 1
            ;;
    esac
done

if [ "$help_shown" = "false" ] && [ "$quiet" = "false" ]; then
    show_ascii_art
fi

shift $((OPTIND - 1))

if [ $# -eq 0 ]; then
    echo "No positional arguments provided." > /dev/tty
else
    for arg in "$@"; do
        input_file="$arg"
        parse_xml
        if [ "$show_graph" = "true" ]; then
            printf "%s\n\n\n" "$graph"
        fi
        if [ -n "$output_file" ]; then
            build > "$output_file"
        else
            build
        fi
    done
fi

if [ "$quiet" = "false" ]; then
    echo "All done! :)" > /dev/tty
fi
