#!/bin/bash

echo " "
echo "===== LoRa GW Cronjob Channel Switch ====="
echo "........ Version 1.1 2019-04-19 .........."
echo "........ sebascheibe@github.com .........."
echo "=========================================="
echo ""

# US915 BAND:
# setup_id setup_freq_0 setup_freq_1 -> Channel_1 Channel_2 Channel_3 Channel_4 Channel_5 Channel_6 Channel_7 Channel_8
#    0	    902700000    903400000   -> 902300000 902500000 902700000 902900000 903100000 903300000 903500000 903700000
#    1      904300000    905000000   -> 903900000 904100000 904300000 904500000 904700000 904900000 905100000 905300000
#    2      905900000    906600000   -> 905500000 905700000 905900000 906100000 906300000 906500000 906700000 906900000
#    3      907500000    908200000   -> 907100000 907300000 907500000 907700000 907900000 908100000 908300000 908500000
#    4      909100000    909800000   -> 908700000 908900000 909100000 909300000 909500000 909700000 909900000 910100000
#    5      910700000    911400000   -> 910300000 910500000 910700000 910900000 911100000 911300000 911500000 911700000
#    6      912300000    913000000   -> 911900000 912100000 912300000 912500000 912700000 912900000 913100000 913300000
#    7      913900000    914600000   -> 913500000 913700000 913900000 914100000 914300000 914500000 914700000 914900000

# EU868 BAND:
# setup_id setup_freq_0 setup_freq_1 -> Channel_1 Channel_2 Channel_3 Channel_4 Channel_5 Channel_6 Channel_7 Channel_8
#    0	    867500000    868500000   -> 867100000 867300000 867500000 867700000 867900000 868100000 868300000 868500000
#    1      869100000    870100000   -> 868700000 868900000 869100000 869300000 869500000 869700000 869900000 870100000

localFolder="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd)"
need_help=NO

# read [OPTION] parameters
for i in "$@"
do
case $i in
    -b=*|--band=*)
    BAND="${i#*=}"
    ;;
    -t=*|--time_interval=*)
    TIME_INTERVAL="${i#*=}"
    ;;
    -c=*|--channel_conf=*)
    CHANNELS="${i#*=}"
    ;;
    -s=*|--gateway_service=*)
    GW_SERVICE="${i#*=}"
    ;;
    -h|--help)
    need_help=YES
    ;;
    *)
    ;;
esac
done

# check 'BAND' parameter
if [[ $BAND != "US915" && $BAND != "EU868" ]]; then
      echo "[ERROR]: Missing or wrong band parameter -b"
      need_help=YES
fi

# check 'TIME_INTERVAL' parameter
time_interval_m_regex='^[0-9]+[m]$'
time_interval_h_regex='^[0-9]+[h]$'
time_interval_d_regex='^[0-9]+[d]$'

if ((${#TIME_INTERVAL}>0)) && [[ $TIME_INTERVAL =~ $time_interval_m_regex ]]; then
      cronjob_schedule="m"
elif ((${#TIME_INTERVAL}>0)) && [[ $TIME_INTERVAL =~ $time_interval_h_regex ]]; then
      cronjob_schedule="h"
elif ((${#TIME_INTERVAL}>0)) && [[ $TIME_INTERVAL =~ $time_interval_d_regex ]]; then
      cronjob_schedule="d"
else
      echo "[ERROR]: Missing or wrong time interval parameter -t"
      need_help=YES
fi

# check 'CHANNELS' parameter
if [[ $BAND == "US915" ]]; then
    # Only allow numeric values of '0' to '7' as valid input:
    band_regex='^[0-7]([,][0-7]|)+$'
fi
if [[ $BAND == "EU868" ]]; then
    # Only allow numeric values of '0' to '1' as valid input:
    band_regex='^[0-1]([,][0-1]|)+$'
fi
if ! [[ $CHANNELS =~ $band_regex ]]; then
        need_help=YES
        echo "[ERROR]: Missing or malformed channel configuration list parameter -c"
    fi

IFS=',' read -r -a channel_conf_array <<< "$CHANNELS"


# print help information 
if [[ $need_help == "YES" ]]; then
    echo ""
    echo "Running in " $localFolder
    echo "Please verify that the script runs inside the /lora/packet_forwarder/lora_pkt_fwd/ folder "
    echo "where global_conf.json file is located!"
    echo " "
    echo "Usage: "
    echo "  sudo bash Cronjob-Channel-Switch.sh [OPTIONS]"
    echo ""
    echo "[Options]: "
    echo ""
    echo "  -t/--time_interval   -> Time interval between each channel switch. [NUM][m/h/d] (minutes, hours or days)"
    echo "                        -t=1m (for one minute interval)"
    echo "                        -t=3h (for three hour interval)"
    echo "                        --time_interval=7d (for seven days interval)"
    echo ""
    echo "  -b/--band            -> LoRaWAN region / frequency band that the gateway is operating in."
    echo "                        -b=US915 (US915 region, 902-928MHz)"
    echo "                        -band=EU868 (EU868 region, 863-870MHz)"
    echo ""
    echo "  -c/--channel_conf    -> List of channel configurations. '0': channels 0-7, '1': channels 8-15, ..."
    echo "                        -c=0,1,5,3"
    echo "                        --channel_conf=0,1,2,3,4,5,6,7"
    echo ""
    echo "  -s/--gateway_service -> Service that runs packet_forwarder and needs to be restarted to effect"
    echo "                          the changes of new channel setup, default service name is 'lorawan-gateway' if no parameter is set."
    echo "                        -s=my_own_gateway_service"
    echo "                        --gateway_service=my_own_gateway_service"
    echo "Examples: "
    echo "  sudo bash Cronjob-Channel-Switch.sh -t=1d -c=0,1 -b=US915"
    echo "  sudo bash Cronjob-Channel-Switch.sh -t=5h -c=0,1,2,3 -s=my-own-gw-service -b=EU868"
    exit 1
fi

localFolder="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd)"

cronjob_index=0
cronjobs_total=${#channel_conf_array[@]}
time_interval=${TIME_INTERVAL:0:$(( ${#TIME_INTERVAL}-1 ))}

if !((${#GW_SERVICE}>0)); then
      GW_SERVICE=lorawan-gateway
    fi

echo "Add new cron jobs:"
for current_channel_conf in "${channel_conf_array[@]}"
 do
   croncmd="/bin/bash $localFolder/LoRa-GW-Channel-Setup.sh $current_channel_conf $BAND && sudo service $GW_SERVICE restart"

   case $cronjob_schedule in
     m) cron_timer="$(( time_interval*cronjob_index ))-59/$(( time_interval*cronjobs_total )) * * * * "
   ;;
     h) cron_timer="* $(( time_interval*cronjob_index ))-23/$(( time_interval*cronjobs_total )) * * * "
   ;;
     d) cron_timer="* * * * $(( time_interval*cronjob_index ))-7/$(( time_interval*cronjobs_total )) "
   ;;
     *) echo "------ Input error. No Schedule? ------";;
   esac

 cronjob="$cron_timer $croncmd"
 # print out new crontab entry
 echo "$cronjob"
 cat <(crontab -l) <(echo "$cronjob") | crontab -

 cronjob_index=$(( cronjob_index+1 ))

 done

echo ""
echo "Done! To review, edit or delete created cron jobs run:"
echo ""
echo "~$ sudo crontab -e"
echo ""
