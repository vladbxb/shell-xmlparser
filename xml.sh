#!/bin/sh

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

echo "$graph" | sed '/^$/d'

