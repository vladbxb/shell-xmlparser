#!/bin/bash

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

echo -e "$graph\n\n"

echo "$graph" | tac > "/tmp/xml_reversed.tmp"

echo "" > "/tmp/xml_reconstructed.tmp"

cat "/tmp/xml_reversed.tmp" | grep -P ":$" > "/tmp/xml_test.tmp"

while IFS= read -r line; do
	if echo "$line" | grep -Pq ":$"; then
		tagname=$(echo "$line" | grep -Po '^[^[]*(?=\[)')
		attributes=$(echo "$line" | grep -Po '(?<=\[)[^]]*(?= _)')
		text=$(echo "$line" | grep -Po '(?<=_text=")[^"]*(?=")')
		if [ -n "$attributes" ]; then
			echo "<$tagname $attributes>$text</$tagname>" | cat - "/tmp/xml_reconstructed.tmp" > "/tmp/xml_temporary.tmp" && mv "/tmp/xml_temporary.tmp" "/tmp/xml_reconstructed.tmp"
		else
			echo "<$tagname>$text</$tagname>" | cat - "/tmp/xml_reconstructed.tmp" > "/tmp/xml_temporary.tmp" && mv "/tmp/xml_temporary.tmp" "/tmp/xml_reconstructed.tmp"
		fi
	else
		children=$(echo "$line" | grep -Po '(?<=:).*')
		tagname=$(echo "$line" | grep -Po '^[^[]*(?=\[)')
		attributes=$(echo "$line" | grep -Po '(?<=\[)[^]]*(?= _)')
		children=$(echo "$children" | sed 's/\([^[ ]*\[[^]]*\]\)/\1\n/g' | sed 's/^[ \t]*//;s/[ \t]*$//')
		firstChild=$(echo "$children" | head -n 1 | grep -Po '^[^[]*(?=\[)')
		lastChild=$(echo "$children" | tail -n 1 | grep -Po '^[^[]*(?=\[)')
		firstChildLineNumber=$(grep -n "$firstChild" "/tmp/xml_reconstructed.tmp" | cut -d: -f1 )
		lastChildLineNumber=$(grep -n "$lastChild" "/tmp/xml_reconstructed.tmp" | cut -d: -f1)
		temp=$((lastChildLineNumber + 1))
		lastChildLineNumber="$temp"
		#echo "$firstChildLineNumber $lastChildLineNumber"
		#echo "$firstChild $lastChild"
		#firstChildLine_escaped=$(echo "$firstChildLine" | sed 's/[][\\]/\\&/g')
		#lastChildLine_escaped=$(echo "$lastChildLine" | sed 's/[][\\]/\\&/g')
		attributes_escaped=$(echo "$attributes" | sed 's/"/\\"/g')
		#echo "$attributes_escaped"

		if [ -n "$attributes_escaped" ]; then
			sed -e "${firstChildLineNumber} i\\<$tagname $attributes_escaped>" /tmp/xml_reconstructed.tmp > /tmp/xml_temporary.tmp && mv /tmp/xml_temporary.tmp /tmp/xml_reconstructed.tmp
			sed -e "${lastChildLineNumber} a\\</$tagname>" /tmp/xml_reconstructed.tmp > /tmp/xml_temporary.tmp && mv /tmp/xml_temporary.tmp /tmp/xml_reconstructed.tmp
		else
			sed "$firstChildLineNumber i\\<$tagname>" /tmp/xml_reconstructed.tmp > /tmp/xml_temporary.tmp && mv /tmp/xml_temporary.tmp /tmp/xml_reconstructed.tmp
			sed "$lastChildLineNumber a\\</$tagname>" /tmp/xml_reconstructed.tmp > /tmp/xml_temporary.tmp && mv /tmp/xml_temporary.tmp /tmp/xml_reconstructed.tmp
		fi
	fi

done < "/tmp/xml_reversed.tmp"

cat "/tmp/xml_reconstructed.tmp"
