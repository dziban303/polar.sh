#!/bin/bash
# shellcheck disable=SC2016

# Usage
# ./reprocess.sh polarheatmap-##########
# This just takes a saved file and runs gnuplot on it all and this time, outputs svg

# Supporting programs needed: apt-get install mawk gnuplot curl jq

#Set heywhatsthat.com site ID here
source .env
hwt=$FEEDER_HEYWHATSTHAT_ID

#Set altitude limits
low=5000
high=25000

#Set plot range in nm
range=230

# Include mlat aircraft? yes/no/mlat - setting to mlat will include only mlat results.
mlat=no

# Hopefully nothing more to change after this point!
set -e
renice -n 10 $$ # renice script so everything runs with lower priority


date=$(date -I)
PWD=$(pwd)
wdir=$(mktemp -d)
HWTDIR=$(mktemp -d)

if [ -z "$hwt" ]; then
	echo "No HeyWhatsThat ID found, I need that!"
	exit 1
else
	echo "Processing heywhatsthat.com data:"

	file=$PWD/upintheair.json

	if [ -f "$file" ]; then
		hwtfile=$(jq --raw-output '.id' "$file")
		if [ ! "$hwt" == "$hwtfile" ]; then
			echo "Heywhatsthat ID has changed - downloading new file"
			rm "$PWD"/upintheair.json
		fi
	fi

	if [[ -f $file ]] && [[ ! -s $file ]]; then
		echo "Removing empty upintheair.json"
		rm "$file"
	fi

	if [ ! -f "$file" ]; then
		echo "Retrieving terrain profiles from heywhatsthat.com:"
		curl "http://www.heywhatsthat.com/api/upintheair.json?id=${hwt}&refraction=0.14&alts=606,1212,1818,2424,3030,3636,4242,4848,5454,6060,6667,7273,7879,8485,9091,9697,10303,10909,11515,12121,13716" >upintheair.json
	fi

	echo ""
	echo "Setting receiver position from heywhatsthat data. If these values do not match what you are expecting, please check the heywhatsthat ID is correct and that it was generated with the correct location"

	lat=$(jq --raw-output '.lat' "$file")
	lon=$(jq --raw-output '.lon' "$file")
	rh=$(jq --raw-output '.elev_amsl' "$file")

	echo "Latitude: " "$lat"
	echo "Longitude: " "$lon"
	echo "Height: " "$rh"
	echo ""

	for i in {0..20}; do
		ring=$(jq --argjson i "$i" --raw-output '.rings | .[$i] | .alt' upintheair.json)
		jq --argjson i "$i" --raw-output '.rings | .[$i] | .points | .[] | @csv' upintheair.json >"$HWTDIR"/"$ring"
	done

	for i in $(ls -1v "$HWTDIR"); do
		mawk -F "," -v rlat="$lat" -v rlon="$lon" -v rh="$rh" -v hwth="$i" \
		'{
	                data(rlat, rlon, rh, $1, $2, hwth)
                }

                function data(lat1, lon1, elev1, lat2, lon2, elev2, lamda, a, c, dlat, dlon, x)
                {
                        dlat = radians(lat2 - lat1)
                        dlon = radians(lon2 - lon1)
                        lat1 = radians(lat1)
                        lat2 = radians(lat2)
                        a = (sin(dlat / 2)) ^ 2 + cos(lat1) * cos(lat2) * (sin(dlon / 2)) ^ 2
                        c = 2 * atan2(sqrt(a), sqrt(1 - a))
                        d = 6371000 * c
                        x = atan2(sin(dlon * cos(lat2)), cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dlon))
                        phi = (x * (180 / 3.1415926) + 360) % 360
                        lamda = (180 / 3.1415926) * atan2((elev2 - elev1) / d - d / (2 * 6371000), 1)
                        printf "%f,%f,%f,%.0f,%f,\n", lat2 * (180 / 3.1415926), lon2, d, phi, lamda
                }

                function radians(degree)
                {
                        # degrees to radians
                        return (degree * (3.1415926 / 180.))
                }' "$HWTDIR"/"$i" >"$HWTDIR"/tmp && mv "$HWTDIR"/tmp "$HWTDIR"/"$i"
	done

	for i in $(ls -1v "$HWTDIR"); do
		max=$(sort -t',' -k3nr "$HWTDIR"/"$i" | head -1)
		max="$max$i"
		echo "$max" >>"$HWTDIR"/max
		min=$(sort -t',' -k3n "$HWTDIR"/"$i" | head -1)
		min="$min$i"
		echo "$min" >>"$HWTDIR"/min
	done
fi

echo "made it this far"

# Copy heatmap to HD at this point
cp $1 "$wdir"/heatmap 

echo "Filtering altitudes"
mawk -v low="$low" -F "," '$4 <= low' "$wdir"/heatmap >"$wdir"/heatmap_low
mawk -v high="$high" -F "," '$4 >= high' "$wdir"/heatmap >"$wdir"/heatmap_high

mawk -F "," '$2 == "large_airport"' "$PWD"/airports.csv >"$wdir"/large
mawk -F "," '$2 == "medium_airport"' "$PWD"/airports.csv >"$wdir"/medium
mawk -F "," '$2 == "small_airport"' "$PWD"/airports.csv >"$wdir"/small
mawk -F "," '$2 == "heliport"' "$PWD"/airports.csv >>"$wdir"/small

gnuplot -c /dev/stdin "$lat" "$lon" "$date" $low $high "$rh" $range "$wdir" "$HWTDIR" <<"EOF"
lat=ARG1
lon=ARG2
date=ARG3
low=ARG4
high=ARG5
rh=ARG6
range=ARG7
dir=ARG8
hwt=ARG9
set terminal svg dashed enhanced size 2000,2000 dynamic font "sans,14"
set datafile separator comma
set object 1 rectangle from screen 0,0 to screen 1,1 fillcolor rgb "black" behind
set output 'polarheatmap-'.date.'.svg'
set border lc rgb "white"
stats dir.'/heatmap' u ($3) noout
set cbrange [(STATS_mean - 2.5 * STATS_stddev):0]
set cblabel "RSSI" tc rgb "white"
set palette rgb 21,22,23
set polar
set angles degrees
set theta clockwise top
set grid polar 45 linecolor rgb "white" front
set colorbox user vertical origin 0.9, 0.80 size 0.02, 0.15
set size square
set title "Signal Heatmap ".date tc rgb "white"
set xrange [-range:range]
set yrange [-range:range]
set rtics 50
set xtics 50
set ytics 50
print "Generating all altitudes heatmap..."
plot dir.'/heatmap' u ($6):($5/1852):($3) with dots lc palette, \
        hwt.'/12121' u  ($4):($3/1852) with lines lc rgb "white" notitle, \
        hwt.'/12121' u ($4):($3/1852) every 359::0::359 with lines lc rgb "white" notitle
set output 'polarheatmap_high-'.date.'.svg'
set title "Signal Heatmap aircraft above ".high." feet - ".date tc rgb "white"
print "Generating high altitude heatmap..."
plot dir.'/heatmap_high' u ($6):($5/1852):($3) with dots lc palette, \
        hwt.'/12121' u  ($4):($3/1852) with lines lc rgb "white" notitle, \
        hwt.'/12121' u ($4):($3/1852) every 359::0::359 with lines lc rgb "white" notitle
set output 'polarheatmap_low-'.date.'.svg'
set title "Signal Heatmap aircraft below ".low." feet - ".date tc rgb "white"
print "Generating low altitude heatmap..."
set xrange [-80:80]
set yrange [-80:80]
set rtics 20
set xtics 20
set ytics 20
plot dir.'/heatmap_low' u ($6):($5/1852):($3) with dots lc palette
set output 'closerange-'.date.'.svg'
set title 'Close range signals - '.date tc rgb "white"
print "Generating close range heatmap"
set xrange [-10:10]
set yrange [-10:10]
set rtics 1
set xtics 1
set ytics 1
plot dir.'/heatmap' u ($6):($5/1852):($3) with points pt 7 ps 0.5 lc palette, \
        dir.'/large' u ($8):($7/1852) with points pt 7 ps 1.5 lc rgb "green" notitle, \
        dir.'/large' u ($8):($7/1852):($1) with labels offset 1,-1 tc rgb "green", \
        dir.'/medium' u ($8):($7/1852) with points pt 7 ps 1.5 lc rgb "green" notitle, \
        dir.'/medium' u ($8):($7/1852):($1) with labels offset 1,-1 tc rgb "green", \
        dir.'/small' u ($8):($7/1852):($1) with labels offset 1,-1 tc rgb "green", \
        dir.'/small' u ($8):($7/1852) with points pt 7 ps 1.5 lc rgb "green" notitle

reset
set terminal svg enhanced size 1920,1080 dynamic font "sans,14"
set datafile separator comma
set output 'elevation-'.date.'.svg'
set object 1 rectangle from screen 0,0 to screen 1,1 fillcolor rgb "black" behind
set cbrange [(STATS_mean - 2.5 * STATS_stddev):0]
set title "Azimuth/Elevation plot" tc rgb "white"
set border lc rgb "white"
set cblabel "RSSI" tc rgb "white"
set colorbox user vertical origin 0.9, 0.75 size 0.02, 0.15
set grid linecolor rgb "white"
set palette rgb 21,22,23
set yrange [-2:15]
set xrange [0:360]
set xtics 45
set ytics 3
print "Generating elevation heatmap..."
plot dir.'/heatmap' u ($6):($7):($3) with dots lc palette, \
        hwt.'/12121' u ($4):($5) with lines lc rgb "white" notitle, \
        dir.'/large' u ($7/1852 <= 50 ? $8 : 1/0):(-1) with points pt 9 ps 2 lc rgb "white" notitle, \
        dir.'/large' u ($7/1852 <= 50 ? $8 : 1/0):(-1):($6) with labels offset 0,-1.5 tc rgb "white" font ",8", \
        dir.'/medium' u ($7/1852 <= 25 ? $8 : 1/0):(-1) with points pt 9 ps 2 lc rgb "white" notitle, \
        dir.'/medium' u ($7/1852 <= 25 ? $8 : 1/0):(-1):($6) with labels offset 0,-1.5 tc rgb "white" font ",8"

set terminal svg enhanced size 1920,1080 dynamic font "sans,14"
set output 'altgraph-'.date.'.svg'
set cblabel "RSSI" tc rgb "white"
set palette rgb 21,22,23
set colorbox user vertical origin 0.9, 0.1 size 0.02, 0.15
set title "Range/Altitude" tc rgb "white"
set xrange [*:250]
set yrange [0:45000]
set xtics 25
set ytics 5000
f(x) = (x**2 / 1.5129) - (rh * 3.3)
print "Generating Range/Altitude plot..."
unset key
plot dir.'/heatmap' u ($5/1852):($4):($3) with dots lc palette, f(x) lt rgb "white" notitle, \
        hwt.'/max' u ($3/1852):($6*3.3) with lines dt 2 lc rgb "green" title "Terrain limit" at end
set output 'closealt-'.date.'.svg'
set title "Close Range/Altitude" tc rgb "white"
set xrange [0:50]
set yrange [-500:10000]
set xtics 5
set ytics 500
print "Generating Close Range altitude plot"
plot dir.'/heatmap' u ($5/1852 <= 50 ? $5/1852 : 1/0):($4 <= 10000 ? $4:1/0):($3) with dots lc palette, \
        dir.'/large' u ($7/1852 <= 50 ? $7/1852 : 1/0):($5) w points pt 9 ps 1 lc rgb "white", \
        dir.'/large' u ($7/1852 <= 50 ? $7/1852 : 1/0):($5-150):($6) with labels tc rgb "white" font ",8", \
        dir.'/medium' u ($7/1852 <= 40 ? $7/1852 : 1/0):($5) w points pt 9 ps 1 lc rgb "white", \
        dir.'/medium' u ($7/1852 <= 40 ? $7/1852 : 1/0):($5-150):($6) with labels tc rgb "white" font ",8", \
        dir.'/small' u ($7/1852 <= 10 ? $7/1852 : 1/0):($5) w points pt 9 ps 1 lc rgb "white", \
        dir.'/small' u ($7/1852 <= 10 ? $7/1852 : 1/0):($5-150):($6) with labels tc rgb "white" font ",8", \
        0 lc rgb "white"

set terminal svg enhanced size 2000,2000 dynamic font "sans,14"
set title "Low altitude with map" tc rgb "white"
set output 'lowmap-'.date.'.svg'
set xrange [-80:80]
set yrange [-80:80]
set xtics 5
set ytics 5
set mxtics
set mytics
set angles degrees
set colorbox user vertical origin 0.9, 0.80 size 0.02, 0.15
set label "" at 0,0 point pointtype 1 ps 2 lc rgb "green" front

print "Generating low heatmap with map overlay"

plot dir.'/heatmap_low' u (($5/1852) * cos (- $6 + 90)):(($5/1852) * sin (-$6 + 90)):($3) w dots lc palette, \
        'world_10m.txt' u ($3/1852):($4/1852) w lines lc rgb "green" notitle, \
        dir.'/large' u ($9/1852):($10/1852) with points pt 7 ps 2 lc rgb "green" notitle, \
        dir.'/large' u ($9/1852):($10/1852):($6) with labels offset char 2,-1 tc rgb "green", \
        dir.'/medium' u ($9/1852):($10/1852) with points pt 7 ps 1 lc rgb "green" notitle, \
        dir.'/medium' u ($9/1852):($10/1852):($6) with labels offset char 2,-1 tc rgb "green", \
        dir.'/small' u ($9/1852):($10/1852) with points pt 7 ps 0.3 lc rgb "green" notitle

set title "Heatmap with map overlay"
set output 'mapol-'.date.'.svg'
set xrange [-range:range]
set yrange [-range:range]
set xtics 25
set ytics 25

plot dir.'/heatmap' u (($5/1852) * cos (- $6 + 90)):(($5/1852) * sin (-$6 + 90)):($3) w dots lc palette, \
        'world_10m.txt' u ($3/1852):($4/1852) w lines lc rgb "green" notitle, \
        hwt.'/12121' u  (($3/1852) * cos (- $4 +90)):(($3/1852) * sin (- $4 + 90)) with lines lc rgb "white" notitle, \
        hwt.'/12121' u (($3/1852) * cos (- $4 +90)):(($3/1852) * sin (- $4 + 90)) every 359::0::359 with lines lc rgb "white" notitle, \
        dir.'/large' u ($9/1852):($10/1852) with points pt 7 ps 1 lc rgb "green" notitle, \
        dir.'/medium' u ($9/1852):($10/1852) with points pt 7 ps 0.75 lc rgb "green" notitle


EOF

#Let's also do altitude.sh while we're here
gnuplot -c /dev/stdin "$wdir"/heatmap "$range" "$date" <<"EOF"

data=ARG1
range=ARG2
date=ARG3

set terminal svg enhanced size 2000,2000 dynamic font "sans,14"
set datafile separator comma
set object 1 rectangle from screen 0,0 to screen 1,1 fillcolor rgb "black" behind
set output 'altmap-'.date.'.svg'

set border lc rgb "white"

set cbrange [0:45000]
set cblabel "Altitude" tc rgb "white"
set palette negative rgb 33,13,10
set polar
set angles degrees
set theta clockwise top
set grid polar 45 linecolor rgb "white"
set colorbox user vertical origin 0.9, 0.80 size 0.02, 0.15


show angles
set size square
set title "Altitude Heatmap" tc rgb "white"
set xrange [-range:range]
set yrange [-range:range]
set rtics 50
set xtics 50
set ytics 50

print "Generating altitudes heatmap..."

plot '< sort -t"," -k4 -r '.data u ($6):($5/1852):($4) with dots lc palette

EOF