# polar.sh

So this is a very modest cleanup / adjustment of [polar.sh from caiusseverus](https://github.com/caiusseverus/adsbcompare).  It's polling only, from either tar1090 or the net-api port of readsb.  It uses mawk instead of gawk to be bit faster and it's tmpfs only with the assumption you'll run this on a machine which has the ram to hold the csv files.  I tend to run it on my desktop and just poll the tiny SBC running readsb.

## Directions
```
apt-get install curl jq mawk gnuplot
```

Next, set up your FEEDER_HEYWHATSTHAT_ID in .env or just manually set hwt in the script AND set the url to either your readsb netapi port or the path to your aircraft.json for tar1090 (the latter is probably more common).  

Now I'd run ./polar.sh 1 5 for a quick 1 minute run to build the world_10m, airports.csv and make sure gnuplot actually outputs a file.  You might not see many plots on such short run, but it's better to complete a run to make sure you have all your programs before starting a 2 hour run.  If that works, go for a longer soak.  I've run the script for up to 24 hours at a time on a machine with plenty of ram / CPU.  

When finished, there is a polarheatmap-<unixtimestamp> file saved.  You can run ./reprocess.sh <file> and it'll output the same series of graphs.