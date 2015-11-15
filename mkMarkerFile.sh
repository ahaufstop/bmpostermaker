#!/bin/bash

##########################################################################
#
#  mkMarkerFile.sh
#
#  Create csv file for leaflet markers from scribus sla file directly
#  - keep external from mkposter2.sh to allow independent runs
#
# Sep 2015
##########################################################################

globStr=""
pWidth=""
pHeight=""
pLat=0
pLong=0

#
# Function to parse the text field we get from object in scribus
#  Possible Format    general Text URL:url IMAGE:urltoimage
#         ( and combinations of that )
#
extractStr () {

eStr=""
# make sure we have a delimiter we can find
# other subs are for tags at very start of line to get delimiter
# using 5 as deliminator ( may have issue with some URL's
fromStr=$( echo $1 | sed -e 's/ URL\:/\XXXURL\:/g' \
                         -e 's/^URL\:/\XXXURL\:/g' \
                         -e 's/^IMAGE\:/\XXXIMAGE\:/g' \
                         -e 's/ IMAGE\:/\XXXIMAGE\:/g'  )

# stick delimiter on end to close search if needed
fromStr=" ""$fromStr""XXX"
filterStr=$2

# make sure there is a TXT tag
if [[ $2 == "TXT:" && ${fromStr:0:4} != "TAG:" ]] ; then fromStr="TXT:""$fromStr" ; fi

eStr=$(echo "$fromStr" | awk -F "$filterStr" '{print substr($2,0,index($2,"XXX")-1);}')


#
if [ -z "$eStr" ]; then 
# if string is empty ...
#  eStr=$filterStr 
   eStr=" "
else
# add http so we dont have to do it in javascript later
  if [[  $2 == "URL:" || $2 == "IMAGE:" ]]; then
# just check http as it may be https ... blah blah blah
     if [[ ${eStr:0:4} != "http" ]] ; then eStr="http://""$eStr" ; fi
  fi
fi

# "return" the value via global string
globStr="$eStr"

}


maptoscreen () {

     xStr=`echo $1 | cut -d "," -f 1`
     yStr=`echo $2 | cut -d "," -f 1`
     pLong=$(echo "scale=2; ( ($xStr/$pWidth) * 220)" | bc) 
     pLat=$(echo "scale=2; ( -50 - ($yStr/$pHeight) * 156)" | bc) 

}

# xmlstarlet stuff
# http://peter-butkovic.blogspot.co.uk/2013/10/xml-processing-in-shell.html 
# http://arstechnica.com/information-technology/2005/11/linux-20051115/2/
# http://www.freesoftwaremagazine.com/articles/xml_starlet 

if [ ! -n "$1" ]
then
  echo "Usage: `basename $0` -f ScribusFileName -m LayerMarker "
  exit $E_BADARGS
fi

# test filename
fileName="testsubway.sla"
markerName="MARKERS"
verbose="FALSE"

for i in "$@"
do
shopt -s nocasematch
     case $i in
        -f) fileName=$2; shift 2;;
        -m) markerName=$2; shift 2;;
        -v) verbose="TRUE"; shift 2;;
        -h|-help) echo -e "\n$0 help;\n -f Scribus sla file \n -m  marker to search for " ; exit ; shift 2;;
     esac
done


if [ ! -f $fileName ]; then
  echo "File does not exist"
  exit $E_BADARGS
fi

if [ "$verbose" == "TRUE" ] ; then
echo $verbose
echo $fileName,$markerName
fi

# <DOCUMENT ANZPAGES="1" PAGEWIDTH="1190.55" PAGEHEIGHT="841.89" 
pWidth=`xmlstarlet sel -t -m "//DOCUMENT" -v "@PAGEWIDTH" -n $fileName`
pHeight=`xmlstarlet sel -t -m "//DOCUMENT" -v "@PAGEHEIGHT" -n $fileName`

if [ "$verbose" == "TRUE" ] ; then
echo $pWidth,$pHeight
fi

# <LAYERS NUMMER="66" LEVEL="31" NAME="OutputText MARKERS" SICHTBAR="1"  ... >
MARKERINFO=`xmlstarlet sel -t -m "//LAYERS" -v "@NUMMER" -o " " -v "@NAME" -n $fileName`
LayerID=$(echo "$MARKERINFO" | grep -i " """$markerName"""" | tail -n 1 | awk '{ print $1 }')


if [ "$LayerID" -gt 0 ]; then
# echo $LayerID

# pull info as one long string to reparse
# Get xy positions for text 
# get the layer items of type Text Box
outStr=$(xmlstarlet sel -t -m  "//PAGEOBJECT[@LAYER='$LayerID' and @PTYPE=4]"  \
                -v "@XPOS" -o ", " -v "@YPOS" -o "," -m "ITEXT" -v "@CH"  -n $fileName)  

if [ "$verbose" == "TRUE" ] ; then
echo $outStr
fi

# first two positions are X amd Y
arrayX=(`echo "$outStr" | awk '{ print $1 }'`) 
arrayY=(`echo "$outStr" | awk '{ print $2 }'`)

OIFS=${IFS}
IFS="
"
arrayTXT=( ` echo "$outStr" | awk -F, '{print $3}' `)
IFS=${OIFS}

# printf '%s,%s,%s,%s\n' "$FOO" "$BAR" "$BAZ" "$QUX"

if [ "$verbose" == "TRUE" ] ; then
    echo "Num Items = " ${#arrayX[@]} 
    echo "arrayX = " ${arrayX[*]}
    echo ------------
    echo "Num Items =" ${#arrayY[@]} 
    echo "arrayY = "${arrayY[*]}
    echo ------------
    echo "Num Items =" ${#arrayTXT[@]} 
    echo "arrayTXT = "${arrayTXT[*]}
fi

# write to csv file
fName=$(basename $fileName .sla )
fName=$fName-$markerName
# echo $fName

# this isnt strictly needed as we overwrite with next command
if [ -e "$fName".csv ]; then rm "$fName".csv ; fi

# printf '%s\n' "Longitude,Latitude,Text,URL,IMAGE,WIDTH,HEIGHT"  > "$fName".csv
#  printf '%s\n' ",,,,,$pageDim"  >> "$fName".csv

printf '%s\n' "Latitude,Longitude,Text,URL,IMAGE"  > "$fName".csv

for ((k=0; k < ${#arrayX[@]}; ++k)); do
# echo "${arrayTXT[k]}"
  extractStr "${arrayTXT[k]}" "TXT:"
  txtStr=$globStr
  extractStr "${arrayTXT[k]}" "URL:"
  urlStr=$globStr
  extractStr "${arrayTXT[k]}" "IMAGE:"
  imgStr=$globStr

# last commas just to pad the width height columns just in case
  maptoscreen ${arrayX[k]} ${arrayY[k]}
  printf '%.2f,%.2f,%s,%s,%s, ,\n' $pLat $pLong "$txtStr" "$urlStr" "$imgStr" >> "$fName".csv

done

echo All Done , File : "$fName".csv created
fi
