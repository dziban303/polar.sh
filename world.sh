#!/bin/bash

# This builds the world / airport datafiles if they aren't already in the repo.

world=$PWD/world_10m.txt

if [ ! -f "$world" ]; then

	wget https://raw.githubusercontent.com/caiusseverus/adsbcompare/master/world_10m.txt
	#cp borders_10m.txt world_10m.txt

	mawk -v rlat="$lat" -v rlon="$lon" 'function data(lat1,lon1,lat2,lon2,  a,c,dlat,dlon,x,t,y) {
    dlat = radians(lat2-lat1)
    dlon = radians(lon2-lon1)
    lat1 = radians(lat1)
    lat2 = radians(lat2)
    a = (sin(dlat/2))^2 + cos(lat1) * cos(lat2) * (sin(dlon/2))^2
    c = 2 * atan2(sqrt(a),sqrt(1-a))
    d = 6371000 * c
    t = atan2(sin(dlon * cos(lat2)), cos(lat1)*sin(lat2)-sin(lat1)*cos(lat2)*cos(dlon))
    phi = (t * (180 / 3.1415926) + 360) % 360
    x = d*cos(radians(-phi)+radians(90))
    y = d*sin(radians(-phi)+radians(90))
    printf("%f,%f,%f,%f,%0.0f\n",lon2,lat2 * (180 / 3.1415926),x,y,d)
        }
    function radians(degree) { # degrees to radians
    return degree * (3.1415926 / 180.)}
        {data(rlat,rlon,$2,$1)}' world_10m.txt > tmp && mv tmp world_10m.txt

	mawk -F "," '!($5 > (350*1852)) || ($1 == 0)' world_10m.txt > tmp && mv tmp world_10m.txt
	sed -i '/^$/d' world_10m.txt
	sed -i -e 's/^0.000000.*$//' world_10m.txt
	sed -i -e :a -e '/./,$!d;/^\n*$/{$d;N;};/\n$/ba' world_10m.txt
	sed -i 'N;/^\n$/D;P;D;' world_10m.txt

fi

ap=$PWD/airports.csv

if [ ! -f "$ap" ]; then

	curl https://davidmegginson.github.io/ourairports-data/airports.csv | cut -d "," -f2,3,5,6,7,14 | tr -d '"' >"$PWD"/airports.csv

	sed -i '1d' "$PWD"/airports.csv

	mawk -F "," -v rlat="$lat" -v rlon="$lon" 'function data(lat1,lon1,lat2,lon2,  a,c,dlat,dlon,x,t,y) {
    dlat = radians(lat2-lat1)
    dlon = radians(lon2-lon1)
    lat1 = radians(lat1)
    lat2 = radians(lat2)
    a = (sin(dlat/2))^2 + cos(lat1) * cos(lat2) * (sin(dlon/2))^2
    c = 2 * atan2(sqrt(a),sqrt(1-a))
    d = 6371000 * c
    t = atan2(sin(dlon * cos(lat2)), cos(lat1)*sin(lat2)-sin(lat1)*cos(lat2)*cos(dlon))
    phi = (t * (180 / 3.1415926) + 360) % 360
    x = d*cos(radians(-phi)+radians(90))
    y = d*sin(radians(-phi)+radians(90))
    printf("%s,%s,%f,%f,%.0f,%s,%.0f,%0.2f,%.0f,%.0f\n",$1,$2,$3,$4,$5,$6,d,phi,x,y)
        }
    function radians(degree) { # degrees to radians
    return degree * (3.1415926 / 180.)}
        {data(rlat,rlon,$3,$4)}' "$PWD"/airports.csv > tmp && mv tmp "$PWD"/airports.csv

	mawk -F "," '!($7 > (350*1852))' "$PWD"/airports.csv > tmp && mv tmp "$PWD"/airports.csv

fi