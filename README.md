# polar.sh

So this is a very modest cleanup / adjustment of [polar.sh from caiusseverus](https://github.com/caiusseverus/adsbcompare).  It's polling only, from either tar1090 or the net-api port of readsb.  It uses mawk instead of gawk to be bit faster and it's tmpfs only with the assumption you'll run this on a machine which has the ram to hold the csv files.  I tend to run it on my desktop and just poll the tiny SBC running readsb.

The generation of world_10m.txt and airports.csv has been moved over to world.sh as once you've done it once you already have the files.  And if you've cloned this repo, you should already have them anyway.  

You do need curl, jq, mawk, gnuplot and bash I believe.  Set the Hey What's that token in the script and the url to your data and run.  Pretty graphs should spit out (I'd run ```./polar.sh 1 5``` the first time just to make sure it all works.  Run for hours after that.)