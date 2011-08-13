#!/bin/bash
TZ="America/Denver"
site=example.no-ip.org:8080

export TZ

while getopts lwhvf:i: arg
do
    case "$arg" in
        i)  interval="$OPTARG";;
        f)  file="$OPTARG";;
        l)  site="$OPTARG";;
        w)  wx=1;;
        v)  OPTIND=$(($OPTIND - 1));break;;
        h|?)  echo "USAGE: $0 [-w] [-i interval] [-f inputfile] [stime_spec [--[etime_spec]]]";
            echo  " where *_spec is \"[[[mm]dd]HH]MM[[cc]yy][.ss]\"";
            echo  " or \"-v -1d ...\", relative to current time";
            echo  " if etime_spec is given, t.dat is not updated";
            exit 2;;
    esac
done
shift $(($OPTIND - 1))

SITE=$site;export SITE

for arg
do
    case $arg in
        "--") shift;break;;
        *) startspec="$startspec $arg";shift;;
    esac
done

#default with no args: last 24 hrs.
#To view since midnight type "pplot 0000"
startspec=${startspec:="-v -1d"}
endspec=$*
# echo "startspec = $startspec"
# echo "endspec = $endspec"
# echo "site = $site"
# echo "interval = $interval"
# echo "file = $file"
# echo "wx = $wx"
# exit;
if [ "$wx" = "1"  ]
then
    . ./wxd.sh
fi

if [ -z "$file" ]
then
    #CMW 10/22/10... use archive file even if there is an endspec
    #echo "not found file or endspec"
    #if either filename is given or there is an endspec we
    #we assume we have all the data we need in file.
    # Otherwise..
#    file="t.dat"
    file="tab"
    rm -f $file
    afile="Archive/all.txt"
    sh ./update
    tt="`date -j $startspec`"
    starttime=`date -v 0H -v 0M -v 0S -j -f "%+" "$tt" "+%a %b %e %H:%M:%S %Y"`
    #echo starttime is $starttime
    if [ ! -f ./taa ]
    then
        ln -s /dev/null taa
    fi
    #discard the beginning of the file..  split outputs it to 'taa' (linked to /dev/null)
    # we use the end after starttime is found, in file 'tab'
    split -p "$starttime" $afile t
    # skip if we're not asking for anything from today
    endsecs="`date -j $endspec "+%s"`"
    todaystartsecs="`date -v 0H -v 0M -v 0S -j "+%s"`"

    if [ "$todaystartsecs" -lt "$endsecs" ]
    then
        # since update the file has until midnight last night,
        # we use today for start and end.
        sday=`date -j  "+%d"`
        smon=`date -j   "+%m"`
        syear=`date -j  "+%Y"`

        eday=`date -j  "+%d"`
        emon=`date -j  "+%m"`
        eyear=`date -j "+%Y"`

        interval=${interval:="60"}
        query="http://$site/dl2/download/download?start_date_day=${sday}&end_date_year=${eyear}&end_date_day=${eday}&output_type=text-tab-lf&start_date_mon=${smon}&start_date_year=${syear}&end_date_mon=${emon}&sieve_interval=$interval"
        echo $query
        lwp-download $query temp$$
        tail +3 temp$$ >> $file
        rm temp$$
    fi
else
    #echo "found file or endspec"
    if [ -z $file ]
    then
        file="t.dat"
    fi
fi


# set up timefmt strings

#echo "date -j $startspec "
tt="`date -j $startspec`"
startrange=`date -j -f "%+" "$tt" "+%m %d %H:%M:%S %Y"`
#echo $startrange
tt="`date -j $endspec`"
endrange=`date -j -f "%+" "$tt" "+%m %d %H:%M:%S %Y"`
#echo $startrange
#echo $endrange
#exit

if [ "$wx" = "1"  ]
then
  # get outside temp data into  Archive/wxdirect.dat
  tt="`date -j $startspec "+%s"`"
  ./convtempfile $tt
  # copy to our tempfile.
  afile=Archive/wxdirect.dat
  wdat=', "w.dat" u 1:(stringcolumn(7) eq "Outdoor" ? $5 : 1/0) t "Outside temp", "v.dat" u 1:(stringcolumn(7) eq "Indoor" ? $5 : 1/0) t "Inside temp" lc rgb "red", "v.dat" u 1:(stringcolumn(7) eq "Indoor" ? $8 : 1/0) t "Slab temp"'
fi

cat > pscript <<EOF
set title "Solarsystem"
set style data line
set xlabel "Date\nTime"
set xdata time
# NOTE this setting is based on current output of date; a little fragile
#set timefmt "%s"
set timefmt "%m %d %H:%M:%S %Y"
#set yrange [ 0:200]
set xrange [ "${startrange}":"${endrange}"]
set format x "%m/%d\n%H:%M"
set grid
set timefmt "%b %d %H:%M:%S %Y"
set key left
plot '$file' using 2:6 t 'Collector' ,  '$file' u 2:8 t 'Tank top', '$file' u 2:7 t 'Tank bottom', '$file' u 2:9 t 'Hydronics return','$file' u 2:10 t 'Solar pump', '$file' u 2:11 t 'Injection pump' ${wdat}
#
EOF
#'w.dat' u 1:(stringcolumn(7) eq "Outdoor" ? \$8 : 1/0) t 'Top top',
/opt/local/bin/gnuplot pscript

