#!/bin/bash

echo " "
echo "=== LoRa GW Continuous Channel Switch ==="
echo "........ Version 1.0 2019-04-19 ........."
echo "..... created by Sebastian Scheibe ......"
echo ".......... ARGENISS SOFTWARE ............"
echo "========================================="
echo " "

# setup_id setup_freq_0 setup_freq_1 -> Channel_1 Channel_2 Channel_3 Channel_4 Channel_5 Channel_6 Channel_7 Channel_8
#    0	    902700000    903400000   -> 902300000 902500000 902700000 902900000 903100000 903300000 903500000 903700000
#    1      904300000    905000000   -> 903900000 904100000 904300000 904500000 904700000 904900000 905100000 905300000
#    2      905900000    906600000   -> 905500000 905700000 905900000 906100000 906300000 906500000 906700000 906900000
#    3      907500000    908200000   -> 907100000 907300000 907500000 907700000 907900000 908100000 908300000 908500000
#    4      909100000    909800000   -> 908700000 908900000 909100000 909300000 909500000 909700000 909900000 910100000
#    5      910700000    911400000   -> 910300000 910500000 910700000 910900000 911100000 911300000 911500000 911700000
#    6      912300000    913000000   -> 911900000 912100000 912300000 912500000 912700000 912900000 913100000 913300000
#    7      913900000    914600000   -> 913500000 913700000 913900000 914100000 914300000 914500000 914700000 914900000

localFolder="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd)"

need_help=NO

#!/bin/bash
for i in "$@"
do
case $i in
    -t=*|--time_interval=*)
    TIME_INTERVALL="${i#*=}"

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
    --default)
    DEFAULT=YES
    ;;
    *)
            # unknown option
    ;;
esac
done

if !((${#TIME_INTERVALL}>0)); then
      need_help=YES
    fi 

if !((${#CHANNELS}>0)); then
      need_help=YES  
    fi

if [ $need_help == "YES" ]; then
    echo "Running in " $localFolder
    echo "Please verify that the script runs inside the /lora/packet_forwarder/lora_pkt_fwd/ folder "
    echo " where global_conf.json file and LoRa-GW-Channel-Setup.sh script are located!"
    echo " "
    echo "Usage: "
    echo "bash continous_channel_switch.sh [OPTIONS]"
    echo "[Options]: "
    echo "  -t/--time_interval -> Time interval between each channel switch." 
    echo "                        -t=1m (for one minute interval)"
    echo "                        -t=3h (for three hour interval)"
    echo "                        --time_interval=7d (for seven days interval)"
    echo "  -c/--channel_conf -> List of channel configurations. '0': channels 0-7, '1': channels 8-15, ..." 
    echo "                        -c=0,1,5,3"
    echo "                        --channel_conf=0,1,2,3,4,5,6,7"
    echo "  -s/--gateway_service -> Service that runs packet_forwarder and needs to be restarted to effect" 
    echo "                          the changes of new channel setup, default service name is 'lorawan-gateway' if no parameter is set." 
    echo "                        -s=my_own_gateway_service"
    echo "                        --gateway_service=my_own_gateway_service"
    echo "Examples: "
    echo "sudo bash continous_channel_switch.sh -t=1d -c=0,1"
    echo "sudo bash continuous_channel_switch.sh -t=1d -c=0,1,2,3 -s=my-own-gw-service"
    exit 1
fi

IFS=',' read -r -a channel_conf_array <<< "$CHANNELS"

while true; do
for current_channel_conf in "${channel_conf_array[@]}"
do
    eval "sudo bash LoRa-GW-Channel-Setup.sh $current_channel_conf"
    echo "Restarting Gateway service."
    if !((${#GW_SERVICE}>0)); then
      GW_SERVICE=lorawan-gateway  
    fi 
    eval "sudo service $GW_SERVICE restart"
    date
    echo "Going to sleep for $TIME_INTERVALL."     
    sleep $TIME_INTERVALL
    echo "Waking up :)"
done

done
