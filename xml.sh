#!/bin/sh

## variabila globala auxiliara
last_child=""


file_checker()
{
    ## functie care verifica existenta fisierului dat ca argument pe masina
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
    ## adauga o proprietate la un element specificat in graf
    # $1 - elementul in care sa adauge
    # $2 - proprietatea pe care sa o adauge ( proprietate + atribut (daca exista) )
    element="$1"
    # dam escape la caracterele speciale
	escaped_element=$(echo "$element" | sed 's/[][\\]/\\&/g')
    property="$2"
    # sterge leading whitespaces din proprietate
    property_trimmed=$(echo "$property" | sed 's/^[ \t]*//')
    # da escape la caracterele speciale din proprietate care pot interfera cu regex-ul
    escaped_property=$(echo "$property_trimmed" | sed 's/[\\&"]/\\&/g')
    # gaseste linia pe care este tatal, apoi adauga proprietatea inauntrul parantezelor patrate, separat de un spatiu
    graph=$(echo "$graph" | sed "/$escaped_element/ s/\[\(.*\)\]/[\1 $escaped_property]/")
}

add_child() {
    ## adauga un copil la un tata in graf
    # $1 - tatal la care sa adauge
    # $2 - copilul pe care sa-l adauge

    parent="$1"
    element="$2"
    # se da escape la caracterele care pot interfera cu regex-ul
    escaped_parent=$(echo "$parent" | sed 's/[][\\]/\\&/g')
    escaped_element=$(echo "$element" | sed 's/[][\\]/\\&/g')
    # se cauta linia pe care este parintele, apoi se pune la finalul acelei linii un spatiu si copilul
    graph=$(echo "$graph" | sed "s/^$escaped_parent:.*/& $escaped_element/")
    # graf ul devine graf + element: pe urmatoarea linie (folosind ; cu 2 echo-uri simulam un newline)
    graph=$(echo "$graph"; echo "$element:")
}


remove_metatags() {
    ## sterge metatag-urile (atributele care incep cu _ , de care ne folosim ca sa stocam date suplimentare care n-ar trebui sa interfereze cu atributele normale)
    # $1 - elementul caruia ii stergem proprietatile ilegale
    cleaned_element="$1"
    ## curatam elementul de proprietatile _self, care indica un tag self_closing si _question, care indica un tag de procesare xml
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
    ## functie recursiva care foloseste algoritmul DFS modificat pentru a parcurge in adancime arborele reprezentat in lista de adiacenta. in loc de depth first search, am putea sa-l numim "depth first traversal".
    ## functia recursiva foloseste doar variabile globale pentru a fi compatibila cu toate shell-urile care se afla in concordanta cu standardul POSIX
    # se suprimeaza output-ul suplimentar (dupa caz)
    if [ "$called_by_build" = "true" ] && [ -z "$output_file" ]; then
        if [ "$quiet" = "false" ]; then
            echo -n "." > /dev/tty
        fi
    fi

    node="$1"

    # se extrage doar numele nodului (chit ca este frunza sau tata)
    if echo "$node" | grep -q ":"; then
        tagname=$(echo "$node" | cut -d: -f1)
    else
        tagname="$node"
    fi

    # variabile auxiliare
    check_for_child="$node:"
    last_child="$tagname"

    # se da escape la caracterele speciale din copilul format cu : la final
	escaped_check_for_child=$(echo "$check_for_child" | sed 's/[][\\]/\\&/g')

    # se incepe extragerea informatiilor referitoare la nodul curent din graf
    # prima oara se verifica daca este frunza (daca exista o linie identica cu aceasta compusa din numele nodului si : la final)
    if echo "$graph" | grep -q "^$escaped_check_for_child$"; then
        # se reia totul pana la : intr-o variabila cu nume corespunzator(ca sa fie mai citibil)
        node_start=$(echo "$node" | grep -oP '^[^:]*')
        # se verifica daca node_start contine metataguri
        # apoi, se sterg acele metataguri cu functia remove_metatags
        # in primele doua ramuri se proceseaza nodurile fara continut text intre tagul de inceput si cel de sfarsit
        if echo "$node_start" | grep -q '\[[^]]*_self[^]]*\]'; then
            node_start=$(remove_metatags "$node_start" | sed 's/\[\]//; s/\[/ /; s/\]//')
            printf "<%s/>\n" "$node_start"
        elif echo "$node_start" | grep -q '\[[^]]*_question[^]]*\]'; then
            node_start=$(remove_metatags "$node_start" | sed 's/\[\]//; s/\[/ /; s/\]//')
            printf "<?%s?>\n" "$node_start"
        else
            # tagul de inceput va contine atribute. noi trebuie sa stergem ] si sa punem spatiu in loc de [ ca sa reformatam continutul cu ce presupune standardul xml
            node_start=$(remove_metatags "$node_start" | sed 's/\[\]//; s/\[/ /; s/\]//')
            
            # apoi se preia continutul text dintre tagul de inceput si de sfarsit din atributul meta proprietatii _text (ce este intre ghilimele).
            text_content=$(echo "$node" | grep -o '_text=".*"' | sed -E 's/_text="(.*)"/\1/')

            # se convertesc caracterele speciale in variantele lor escaped. asa sunt stocate in graf
            text_content=$(echo "$text_content" | sed 's/\\&/\&amp;/g; s/\\</\&lt;/g; s/\\>/\&gt;/g; s/\\"/\&quot;/g; s/\\'\''/\&apos;/g')
            # tagul de sfarsit este doar numele tagului fara partea de atribute
            node_end=$(echo "$node" | sed 's/\[.*//')
            printf "<%s>%s</%s>\n" "$node_start" "$text_content" "$node_end"
        fi
    else
        # se preia iar doar numele tagului dupa caz
        if echo "$node" | grep -q ":"; then
            tagname=$(echo "$node" | cut -d: -f1)
        else
            tagname="$node"
        fi
        ## cazul unui tag imbricat
        # se initializeaza / se da push pe stiva func_stack care tine evidenta de nodurile deschise
        func_stack="$func_stack @$node"
        # se aduce tagname ul in forma unui tag de deschidere
        tagname=$(remove_metatags "$tagname" | sed 's/\[\]//; s/\[/ /; s/\]//')
        # apoi se afiseaza doar el (urmatorul continut fiind imbricat in el)
        printf "<%s>\n" "$tagname"
        # se da escape la caracterele speciale
	    escaped_node=$(echo "$node" | sed 's/[][\\]/\\&/g')
        # se verifica daca nodul respectiv are o linie in care sunt precizati copii (descendenti directi)
        check_for_children=$(echo "$graph" | grep "^$escaped_node:.*")
        # copii sunt preluati prin stergerea a tuturor caracterelor pana la : (astfel ramane doar ce este dupa : )
        children=$(echo "$check_for_children" | sed 's/^.*://')
        # iteram prin fiecare copil (sunt de fapt pusi intr-o lista, asemanator ca stivele de mai sus)
        while echo "$children" | grep -qP '[^\s]+\[.*?\]'; do
            # se separa copiii pe linii apoi se preia primul copil din lista
            element=$(echo "$children" | grep -oP '[^\s]+\[.*?\]' | head -n1)
            # se da push la copilul curent pe stiva de elemente
            element_stack="$element_stack @$element"
            # se da push la lista de copii pe stiva de copii
            children_stack="$children_stack @$children"

            # apoi se face apel recursiv al functiei. in momentul intoarcerii din apeluri, functia se va folosi de stivele auxiliare pentru a retine copiii precedenti, elementul la care se afla atunci, etc. facem acest lucru din cauza ca nu putem avea variabile globale (ksh nu ar fi mers, variabilele locale nu sunt in standardul POSIX)
            reconstruct_xml "$element"
            # se preia ultima lista de copii
            children=$(echo "$children_stack" | sed 's/.* @//')
            # apoi se da pop la stiva de liste de copii
            children_stack=$(echo "$children_stack" | sed 's/\(.*\) @.*$/\1/')
            # asemenea la elementul curent  si la stiva de elemente
            element=$(echo "$element_stack" | sed 's/.*@//')
            element_stack=$(echo "$element_stack" | sed 's/\(.*\) @.*$/\1/')
            # apoi se da pop la copilul care abia a fost procesat
            children=$(echo "$children" | sed "s/$(printf '%s' "$element" | sed 's/[][\&\/]/\\&/g')//" | sed 's/^ *//;s/ *$//')
        done
        # se preia ultimul element din stiva de noduri
        node=$(echo "$func_stack" | sed 's/.*@//')
        # se da pop la stiva de noduri
        func_stack=$(echo "$func_stack" | sed 's/\(.*\) @.*$/\1/')
        # apoi este procesat tagul de sfarsit cu tehnica de mai sus
        node_end=$(echo "$node" | sed 's/\[.*//')
        # e afisat pe o singura linie acesta (s-a terminat imbricarea)
        printf "</%s>\n" "$node_end"
    fi
}

pre_process() {
    # pre-procesarea fisierului consta in eliminarea indentarilor de pe fiecare rand, stergerea newline-urilor (tragerea a tuturor liniilor pe una singura), eliminarea existentei comentariilor (asemanator cu ce fac alte parsere de xml, de exemplu xmllint sau xmlstarlet), plasarea unui newline inainte si dupa fiecare < sau > pentru a simula cel mai dificil caz, apoi stergerea randurilor goale. acesta este un fisier normalizat
    normalized_data=$(sed 's/^[ \t]*//;s/[ \t]*$//' "$1" | tr '\n' ' ' | sed 's/>[ ]*</></g'| sed 's/<!--[^>]*-->//g' | sed -e 's/>/&\n/g' -e 's/>/\n&/g' -e 's/</\n&/g' -e 's/</&\n/g' | sed '/^$/d')
    echo "$normalized_data"

}

parse_xml() {
    ## se parseaza fisierul xml. citirea se face rand cu rand

    # se verifica existenta fisierului pe sistem
    file_checker "$input_file"

    # daca nu este, oprim executia
    if [ "$?" = "1" ]; then
        exit
    fi

    # se reseteaza continutul din fisierul temporar care stocheaza continutul pre-procesat
    echo "" > /tmp/pre_processed_xml.tmp

    # eye candy
    if [ "$quiet" = "false" ]; then
        echo "" > /dev/tty
        echo -n "Parsing" > /dev/tty
    fi

    # se salveaza continutul nou pre-procesat
    pre_process "$input_file" > /tmp/pre_processed_xml.tmp


    # variabile auxiliare initializate
    graph=""
    stack=""

    # fiecare nod este serializat pentru a asigura unicitatea lor (astfel se pot repeta identic)
    serial="1"

    # parcurgem linie cu linie, stergand leading si trailing whitespaces cu IFS=
    while IFS= read -r line; do
        # se preia primul si ultimul caracter
        fc=$(echo "$line" | cut -c1)
        lc=$(echo "$line" | rev | cut -c1)
        # detectie deschidere tag
        if [ "$fc" = "<" ]; then
            tag_open="true"
            element_open="true"
        # detectie inchidere tag
        elif [ "$fc" = ">" ]; then
            tag_open="false"
        # detectie deschidere element
        elif [ "$tag_open" = "true" ]; then # procesam numele tagului si atributele
            # detectie inchidere element
            if [ "$fc" = "/" ]; then
                stack=$(echo "$stack" | sed 's/\(.*\) @.*$/\1/')
                element_open="false"
            # procesare tag deschidere
            else
                # se preia numele tagului si atributele sale separat
                tagname=$(echo "$line" | sed 's/\/$//' | sed 's/^\([^ \t]*\).*/\1/')
                attributes=$(echo "$line" | sed "s/$tagname//" | sed 's/[ \t]*$//')
                # detectie tag de tip self closing (ex: <br/> din html)
                if [ "$lc" = "/" ]; then
                    # / de la final este sters
                    attributes=$(echo "$attributes" | sed 's/\/$//')
                    # este adaugat metatag-ul _self pentru a tine evidenta de aceasta proprietate importanta pentru reconstruire
                    element="${tagname}[_$serial _self $attributes]"
                    # detectie taguri de procesare xml
                elif [ "$lc" = "?" ]; then
                    # se sterge ? din tagname ( a fost preluat anterior )
                    tagname=$(echo "$tagname" | sed 's/^?//')
                    # se sterge si ultimul ? din atribute
                    attributes=$(echo "$attributes" | sed 's/?$//')
                    # si se adauga metatag-ul _question pe acelasi principiu
                    element="${tagname}[_$serial _question $attributes]"
                else
                    # altfel, este adaugat doar serialul
                    element="${tagname}[_$serial $attributes]"
                fi
                # serialul se incrementeaza
                temp=$((serial + 1))
                serial="$temp"
                # initializam graful
                if [ -z "$graph" ]; then
                    graph="$element:"
                # altfel, punem in variabila parent tatal
                elif [ -n "$stack" ]; then
                    parent=$(echo "$stack" | sed 's/.*@//')
                    # dar daca acesta nu exista, sarim peste
                    if [ -z "$parent" ]; then
                        break
                    else
                        # daca exista, adaugam elementul gasit la tata in graf
                        add_child "$parent" "$element"
                    fi
                else
                    #altfel, punem elementul curent pe urmatoarea linie in graf, devenind posibil tata (sau frunza)
                    graph=$(echo "$graph"; echo "$element:")
                fi
                # daca elementul este self closing sau tag de procesare, nu are rost sa-l bagam pe stiva, deoarece incepe si se termina pe un singur rand.
                if [ "$lc" != "/" ] && [ "$lc" != "?" ]; then
                    stack="$stack @$element"
                fi
            fi
            # procesare continut text din element
        elif [ "$element_open" = "true" ] && [ "$tag_open" = "false" ]; then
            # acesta pur si simplu o sa fie pe o linie separata si ne usureaza munca considerabil de mult
            text="_text=\"$line\""
            # se insereaza caracterele speciale in graf ca realmente acestea dar escaped
            text=$(echo "$text" | sed -e 's/&amp;/\\\&/g' -e 's/&lt;/\\</g' -e 's/&gt;/\\>/g' -e 's/&quot;/\\\"/g' -e "s/&apos;/\\\'/g")
            # se adauga metatag-ul text
            add_property "$element" "$text"
        fi
        # eye candy
        if [ "$quiet" = "false" ]; then
            echo -n "."
        fi
    done < "/tmp/pre_processed_xml.tmp"
    # mesaj de finalizare parsare
    if [ "$quiet" = "false" ]; then
        echo "" > /dev/tty
        echo "Done!" > /dev/tty
        echo "" > /dev/tty
        echo "" > /dev/tty
    fi
}

indent_xml_file() {
    ## o functie care primeste un fisier formatat xml si il indenteaza
    file_to_indent="$1"
    # variabila auxiliara pentru nivelul de adancime al indentatiei
    depth=0

    # parcurgem linie cu linie (si verificam ca randul sa nu fie gol)
    while IFS= read -r line || [ -n "$line" ]; do
        # eye candy
        if [ "$called_by_build" = "true" ] && [ -z "$output_file" ]; then
            if [ "$quiet" = "false" ]; then
                echo -n "." > /dev/tty
            fi
        fi
        # stergem toate leading si trailing whitespaces si tab-uri
        trimmed_line=$(echo "$line" | sed 's/^[ \t]*//;s/[ \t]*$//')

        # daca randul este gol fara spatii trecem peste
        [ -z "$trimmed_line" ] && continue

        # daca este gasit tag de sfarsit, se scade identatia
        if echo "$trimmed_line" | grep -q '^</'; then
            depth=$((depth - 1))
        fi

        # apoi se afiseaza indentatia si linia curenta. implicit o indentatie pentru noi este formata din 4 spatii
        printf "%s%s\n" "$(printf ' %.0s' $(seq 1 $((depth * 4))))" "$trimmed_line" | sed 's/^ //'

        # daca este gasit un tag de inceput, indentatia este crescuta
        if echo "$trimmed_line" | grep -q '^<[^/!?][^>]*[^/]>$'; then
            depth=$((depth + 1))
        fi
    done < "$file_to_indent"

}

build() {
    ## avand un graf, se reconstruieste fisierul bazat doar pe structura acestuia
    # se goleste fisierul temporar in care va fi stocat rezultatul
    echo "" > /tmp/reconstructed_xml.tmp
    # eye candy
    if [ "$quiet" = "false" ]; then
        echo "" > /dev/tty
        echo -n "Rebuilding graph" > /dev/tty
    fi
    # se liniaza graful. aceasta este o metoda veche care ne-a ajutat sa prevenim erori acum mai mult timp. o lasam pentru compatibilitate
    graph_numbered=$(echo "$graph" | nl -s ":" -n ln -w 1)
    line_number="1"

    # se initializeaza stivele auxiliare
    func_stack=""
    indent_stack=""
    children_stack=""

    while echo "$graph_numbered" | grep -q "^$line_number"; do
        # alta variabila auxiliara care tine ultimul copil traversat
        last_child=""
        # se preia primul copil al "radacinei" (de pe cel mai mic nivel)
        root_child=$(echo "$graph_numbered" | grep "^$line_number:" | cut -d: -f2)
        called_by_build="true"
        # si se construieste structura sa imbricata sau neimbricata
        reconstruct_xml "$root_child" >> /tmp/reconstructed_xml.tmp
        # este retinut ultimul copil, apoi
        escaped_last_child=$(echo "$last_child" | sed 's/[][\\]/\\&/g')
        # este cautat in graful liniat amplasarea acestuia
        line_number=$(echo "$graph_numbered" | grep "$escaped_last_child:$" | cut -d: -f1)
        # in functie de linia gasita, se cauta pe urmatoarea linie (nu este necesar, dar la un moment dat ne ajuta sa prevenim erori)
        temp=$((line_number + 1))
        line_number="$temp"
    done

    # indenteaza fisierul nou construit
    indent_xml_file "/tmp/reconstructed_xml.tmp" > /tmp/indented_xml.tmp

    # eye candy
    if [ "$quiet" = "false" ]; then
        echo "" > /dev/tty
        echo "Done!" > /dev/tty
        echo "" > /dev/tty
        echo "" > /dev/tty
    fi
    cat /tmp/indented_xml.tmp
}

# eye candy
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
    ## mesaj util de ajutor. se afiseaza cu switch-ul -h
    echo "Usage: $0 [-q] [-h] [-g] [-o output_file] [xml_file1] [xml_file2] ... [xml_fileN]" > /dev/tty
    echo "  -q                Prints only necessary output to console (quiet mode)" > /dev/tty
    echo "  -h                Show this help message" > /dev/tty
    echo "  -g                Show adjacency list" > /dev/tty
    echo "  -o output_file    Choose an output file for the rebuilt XML file" > /dev/tty
}

## se initializeaza diverse variabile auxiliare
input_file=""
output_file=""
quiet="false"
help_shown="false"
show_graph="false"
called_by_build="false"

## se foloseste getopts pentru a parcurge intr-un mod standard POSIX toate switch-urile si argumentele pozitionale pasate. aceasta implementare urmeaza Ghidul de Sintaxa pentru Argumente Utilitare POSIX.
while getopts ":qhgo:" opt; do
    case "$opt" in
        # pentru parametrul quiet, suprimam output-ul care nu este necesar (eye candy). functionalitate utila pentru piping
        q)
            quiet="true"
            ;;
        # pentru parametrul help, se afiseaza ghidul de utilizare al programului
        h)
            help_shown="true"
            show_ascii_art
            usage
            ;;
        # pentru parametrul graph, se afiseaza arborele construit prin parsare
        g)
            show_graph="true"
            ;;
        # pentru parametrul output, se poate specifica un fisier de output al procesarii
        o)
            output_file="$OPTARG"
            ;;
        # cazuri de eroare
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

# afisam eye candy
if [ "$help_shown" = "false" ] && [ "$quiet" = "false" ]; then
    show_ascii_art
fi

# eliminam toate switch-urile pentru a procesa un numar arbitrar de argumentele pozitionale
shift $((OPTIND - 1))

if [ $# -eq 0 ]; then
    echo "No positional arguments provided." > /dev/tty
else
    # se itereaza prin fiecare si se parseaza
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

# mesaj de finalizare program
if [ "$quiet" = "false" ]; then
    echo "All done! :)" > /dev/tty
fi
