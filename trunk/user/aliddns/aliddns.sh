#!/bin/sh
#copyright by hiboy
#source /etc/storage/init.sh
#ACTION=$1
export PATH='/etc/storage/bin:/tmp/script:/etc/storage/script:/opt/usr/sbin:/opt/usr/bin:/opt/sbin:/opt/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin'
export LD_LIBRARY_PATH=/lib:/opt/lib
ACTION=$1
scriptfilepath=$(cd "$(dirname "$0")"; pwd)/$(basename $0)
#echo $scriptfilepath
scriptpath=$(cd "$(dirname "$0")"; pwd)
#echo $scriptpath
scriptname=$(basename $0)

aliddns_enable=`nvram get aliddns_enable`
[ -z $aliddns_enable ] && aliddns_enable=0 && nvram set aliddns_enable=0
if [ "$aliddns_enable" != "0" ] ; then
#nvramshow=`nvram showall | grep '=' | grep aliddns | awk '{print gensub(/'"'"'/,"'"'"'\"'"'"'\"'"'"'","g",$0);}'| awk '{print gensub(/=/,"='\''",1,$0)"'\'';";}'` && eval $nvramshow

aliddns_interval=`nvram get aliddns_interval`
aliddns_ak=`nvram get aliddns_ak`
aliddns_sk=`nvram get aliddns_sk`
aliddns_domain=`nvram get aliddns_domain`
aliddns_name=`nvram get aliddns_name`
aliddns_domain2=`nvram get aliddns_domain2`
aliddns_name2=`nvram get aliddns_name2`
aliddns_domain6=`nvram get aliddns_domain6`
aliddns_name6=`nvram get aliddns_name6`
aliddns_ttl=`nvram get aliddns_ttl`

if [ "$aliddns_domain"x != "x" ] && [ "$aliddns_name"x = "x" ] ; then
	aliddns_name="www"
	nvram set aliddns_name="www"
fi
if [ "$aliddns_domain2"x != "x" ] && [ "$aliddns_name2"x = "x" ] ; then
	aliddns_name2="www"
	nvram set aliddns_name2="www"
fi
if [ "$aliddns_domain6"x != "x" ] && [ "$aliddns_name6"x = "x" ] ; then
	aliddns_name6="www"
	nvram set aliddns_name6="www"
fi

IPv6=0
domain_type=""
hostIP=""
domain=""
name=""
name1=""
timestamp=`date -u "+%Y-%m-%dT%H%%3A%M%%3A%SZ"`
aliddns_record_id=""
[ -z $aliddns_interval ] && aliddns_interval=600 && nvram set aliddns_interval=$aliddns_interval
[ -z $aliddns_ttl ] && aliddns_ttl=600 && nvram set aliddns_ttl=$aliddns_ttl
aliddns_renum=`nvram get aliddns_renum`

fi

if [ ! -z "$(echo $scriptfilepath | grep -v "/tmp/script/" | grep aliddns)" ]  && [ ! -s /tmp/script/_aliddns ]; then
	mkdir -p /tmp/script
	{ echo '#!/bin/sh' ; echo $scriptfilepath '"$@"' '&' ; } > /tmp/script/_aliddns
	chmod 777 /tmp/script/_aliddns
fi

aliddns_restart () {

relock="/var/lock/aliddns_restart.lock"
if [ "$1" = "o" ] ; then
	nvram set aliddns_renum="0"
	[ -f $relock ] && rm -f $relock
	return 0
fi
if [ "$1" = "x" ] ; then
	if [ -f $relock ] ; then
		logger -t "???aliddns???" "????????????????????????????????????"`cat $relock`"????????????????????????????????????"
		exit 0
	fi
	aliddns_renum=${aliddns_renum:-"0"}
	aliddns_renum=`expr $aliddns_renum + 1`
	nvram set aliddns_renum="$aliddns_renum"
	if [ "$aliddns_renum" -gt "2" ] ; then
		I=19
		echo $I > $relock
		logger -t "???aliddns???" "????????????????????????????????????"`cat $relock`"????????????????????????????????????"
		while [ $I -gt 0 ]; do
			I=$(($I - 1))
			echo $I > $relock
			sleep 60
			[ "$(nvram get aliddns_renum)" = "0" ] && exit 0
			[ $I -lt 0 ] && break
		done
		nvram set aliddns_renum="0"
	fi
	[ -f $relock ] && rm -f $relock
fi
nvram set aliddns_status=0
eval "$scriptfilepath &"
exit 0
}

aliddns_get_status () {

A_restart=`nvram get aliddns_status`
B_restart="$aliddns_enable$aliddns_interval$aliddns_ak$aliddns_sk$aliddns_domain$aliddns_name$aliddns_domain2$aliddns_name2$aliddns_domain6$aliddns_name6$aliddns_ttl$(cat /etc/storage/ddns_script.sh | grep -v '^#' | grep -v "^$")"
B_restart=`echo -n "$B_restart" | md5sum | sed s/[[:space:]]//g | sed s/-//g`
if [ "$A_restart" != "$B_restart" ] ; then
	nvram set aliddns_status=$B_restart
	needed_restart=1
else
	needed_restart=0
fi
}

aliddns_check () {

aliddns_get_status
if [ "$aliddns_enable" != "1" ] && [ "$needed_restart" = "1" ] ; then
	[ ! -z "$(ps -w | grep "$scriptname keep" | grep -v grep )" ] && logger -t "???aliddns???????????????" "?????? aliddns" && aliddns_close
	{ kill_ps "$scriptname" exit0; exit 0; }
fi
if [ "$aliddns_enable" = "1" ] ; then
	if [ "$needed_restart" = "1" ] ; then
		aliddns_close
		eval "$scriptfilepath keep &"
		exit 0
	else
		[ -z "$(ps -w | grep "$scriptname keep" | grep -v grep )" ] || [ ! -s "`which curl`" ] && aliddns_restart
	fi
fi
}

aliddns_keep () {
aliddns_start
logger -t "???AliDDNS???????????????" "??????????????????"
while true; do
sleep $aliddns_interval
[ ! -s "`which curl`" ] && aliddns_restart
#nvramshow=`nvram showall | grep '=' | grep aliddns | awk '{print gensub(/'"'"'/,"'"'"'\"'"'"'\"'"'"'","g",$0);}'| awk '{print gensub(/=/,"='\''",1,$0)"'\'';";}'` && eval $nvramshow
aliddns_enable=`nvram get aliddns_enable`
[ "$aliddns_enable" = "0" ] && aliddns_close && exit 0;
if [ "$aliddns_enable" = "1" ] ; then
	aliddns_start
fi
done
}

kill_ps () {

COMMAND="$1"
if [ ! -z "$COMMAND" ] ; then
	eval $(ps -w | grep "$COMMAND" | grep -v $$ | grep -v grep | awk '{print "kill "$1";";}')
	eval $(ps -w | grep "$COMMAND" | grep -v $$ | grep -v grep | awk '{print "kill -9 "$1";";}')
fi
if [ "$2" == "exit0" ] ; then
	exit 0
fi
}

aliddns_close () {

kill_ps "/tmp/script/_aliddns"
kill_ps "_aliddns.sh"
kill_ps "$scriptname"

}

aliddns_start () {
IPv6=0
if [ "$aliddns_domain"x != "x" ] && [ "$aliddns_name"x != "x" ] ; then
	sleep 1
	timestamp=`date -u "+%Y-%m-%dT%H%%3A%M%%3A%SZ"`
	aliddns_record_id=""
	domain="$aliddns_domain"
	name="$aliddns_name"
	arDdnsCheck $aliddns_domain $aliddns_name
fi
if [ "$aliddns_domain2"x != "x" ] && [ "$aliddns_name2"x != "x" ] ; then
	sleep 1
	timestamp=`date -u "+%Y-%m-%dT%H%%3A%M%%3A%SZ"`
	aliddns_record_id=""
	domain="$aliddns_domain2"
	name="$aliddns_name2"
	arDdnsCheck $aliddns_domain2 $aliddns_name2
fi
if [ "$aliddns_domain6"x != "x" ] && [ "$aliddns_name6"x != "x" ] ; then
	IPv6=1
	sleep 1
	timestamp=`date -u "+%Y-%m-%dT%H%%3A%M%%3A%SZ"`
	aliddns_record_id=""
	domain="$aliddns_domain6"
	name="$aliddns_name6"
	arDdnsCheck $aliddns_domain6 $aliddns_name6
fi

}

urlencode() {
	# urlencode <string>
	out=""
	while read -n1 c
	do
		case $c in
			[a-zA-Z0-9._-]) out="$out$c" ;;
			*) out="$out`printf '%%%02X' "'$c"`" ;;
		esac
	done
	echo -n $out
}

enc() {
	echo -n "$1" | urlencode
}

send_request() {
	args="AccessKeyId=$aliddns_ak&Action=$1&Format=json&$2&Version=2015-01-09"
	hash=$(echo -n "GET&%2F&$(enc "$args")" | openssl dgst -sha1 -hmac "$aliddns_sk&" -binary | openssl base64)
	curl -L -s "http://alidns.aliyuncs.com/?$args&Signature=$(enc "$hash")"
}

get_recordid() {
	grep -Eo '"RecordId":"[0-9]+"' | cut -d':' -f2 | tr -d '"' |head -n1
}

get_recordIP() {
	sed -e "s/"'"TTL":'"/"' \n '"/g" | grep '"Type":"'$domain_type'"' | grep -Eo '"Value":"[^"]*"' | awk -F 'Value":"' '{print $2}' | tr -d '"' |head -n1
}

query_recordInfo() {
	send_request "DescribeDomainRecordInfo" "RecordId=$1&SignatureMethod=HMAC-SHA1&SignatureNonce=$timestamp&SignatureVersion=1.0&Timestamp=$timestamp"
}

query_recordid() {
	send_request "DescribeSubDomainRecords" "SignatureMethod=HMAC-SHA1&SignatureNonce=$timestamp&SignatureVersion=1.0&SubDomain=$name1.$domain&Timestamp=$timestamp&Type=$domain_type"
}

update_record() {
	hostIP_tmp=$(enc "$hostIP")
	send_request "UpdateDomainRecord" "RR=$name1&RecordId=$1&SignatureMethod=HMAC-SHA1&SignatureNonce=$timestamp&SignatureVersion=1.0&TTL=$aliddns_ttl&Timestamp=$timestamp&Type=$domain_type&Value=$hostIP_tmp"
}

add_record() {
	hostIP_tmp=$(enc "$hostIP")
	send_request "AddDomainRecord&DomainName=$domain" "RR=$name1&SignatureMethod=HMAC-SHA1&SignatureNonce=$timestamp&SignatureVersion=1.0&TTL=$aliddns_ttl&Timestamp=$timestamp&Type=$domain_type&Value=$hostIP_tmp"
}

arDdnsInfo() {
case  $name  in
	  \*)
		name1=%2A
		;;
	  \@)
		name1=%40
		;;
	  *)
		name1=$name
		;;
esac

	if [ "$IPv6" = "1" ]; then
		domain_type="AAAA"
	else
		domain_type="A"
	fi
	timestamp=`date -u "+%Y-%m-%dT%H%%3A%M%%3A%SZ"`
	# ????????????ID
	aliddns_record_id=""
	aliddns_record_id=`query_recordid | get_recordid`
	sleep 1
	timestamp=`date -u "+%Y-%m-%dT%H%%3A%M%%3A%SZ"`
	# ??????????????????IP
	recordIP=`query_recordInfo $aliddns_record_id | get_recordIP`
	
	if [ "$IPv6" = "1" ]; then
	echo $recordIP
	return 0
	else
	# Output IP
	case "$recordIP" in 
	[1-9]*)
		echo $recordIP
		return 0
		;;
	*)
		echo "Get Record Info Failed!"
		#logger -t "???AliDDNS???????????????" "???????????????????????????"
		return 1
		;;
	esac
	fi
}

# ??????????????????
# ??????: ???????????????
arNslookup() {
mkdir -p /tmp/arNslookup
nslookup $1 | tail -n +3 | grep "Address" | awk '{print $3}'| grep -v ":" | sed -n '1p' > /tmp/arNslookup/$$ &
I=5
while [ ! -s /tmp/arNslookup/$$ ] ; do
		I=$(($I - 1))
		[ $I -lt 0 ] && break
		sleep 1
done
killall nslookup
if [ -s /tmp/arNslookup/$$ ] ; then
cat /tmp/arNslookup/$$ | sort -u | grep -v "^$"
rm -f /tmp/arNslookup/$$
else
	curltest=`which curl`
	if [ -z "$curltest" ] || [ ! -s "`which curl`" ] ; then
		Address="`wget -T 5 -t 3 --no-check-certificate --quiet --output-document=- http://119.29.29.29/d?dn=$1`"
		if [ $? -eq 0 ]; then
		echo "$Address" |  sed s/\;/"\n"/g | sed -n '1p' | grep -E -o '([0-9]+\.){3}[0-9]+'
		fi
	else
		Address="`curl -k -s http://119.29.29.29/d?dn=$1`"
		if [ $? -eq 0 ]; then
		echo "$Address" |  sed s/\;/"\n"/g | sed -n '1p' | grep -E -o '([0-9]+\.){3}[0-9]+'
		fi
	fi
fi
}

arNslookup6() {
mkdir -p /tmp/arNslookup
nslookup $1 | tail -n +3 | grep "Address" | awk '{print $3}'| grep ":" | sed -n '1p' > /tmp/arNslookup/$$ &
I=5
while [ ! -s /tmp/arNslookup/$$ ] ; do
		I=$(($I - 1))
		[ $I -lt 0 ] && break
		sleep 1
done
killall nslookup
if [ -s /tmp/arNslookup/$$ ] ; then
	cat /tmp/arNslookup/$$ | sort -u | grep -v "^$"
	rm -f /tmp/arNslookup/$$
fi
}

# ??????????????????
# ??????: ????????? ?????????
arDdnsUpdate() {
case  $name  in
	  \*)
		name1=%2A
		;;
	  \@)
		name1=%40
		;;
	  *)
		name1=$name
		;;
esac
	if [ "$IPv6" = "1" ]; then
		domain_type="AAAA"
	else
		domain_type="A"
	fi
I=3
aliddns_record_id=""
while [ "$aliddns_record_id" = "" ] ; do
	I=$(($I - 1))
	[ $I -lt 0 ] && break
	# ????????????ID
	timestamp=`date -u "+%Y-%m-%dT%H%%3A%M%%3A%SZ"`
	aliddns_record_id=`query_recordid | get_recordid`
	echo "recordID $aliddns_record_id"
	sleep 1
done
	timestamp=`date -u "+%Y-%m-%dT%H%%3A%M%%3A%SZ"`
if [ "$aliddns_record_id" = "" ] ; then
	aliddns_record_id=`add_record | get_recordid`
	echo "added record $aliddns_record_id"
	logger -t "???AliDDNS???????????????" "???????????????  $aliddns_record_id"
else
	update_record $aliddns_record_id
	echo "updated record $aliddns_record_id"
	logger -t "???AliDDNS???????????????" "???????????????  $aliddns_record_id"
fi
# save to file
if [ "$aliddns_record_id" = "" ] ; then
	# failed
	nvram set aliddns_last_act="`date "+%Y-%m-%d %H:%M:%S"`   ????????????"
	logger -t "???AliDDNS???????????????" "????????????"
	return 1
else
	nvram set aliddns_record_id="$aliddns_record_id"
	nvram set aliddns_last_act="`date "+%Y-%m-%d %H:%M:%S"`   ???????????????$hostIP"
	logger -t "???AliDDNS???????????????" "??????????????? $hostIP"
	return 0
fi

}

# ??????????????????
# ??????: ????????? ?????????
arDdnsCheck() {
	#local postRS
	#local lastIP
	source /etc/storage/ddns_script.sh
	hostIP=$arIpAddress
	hostIP=`echo $hostIP | head -n1 | cut -d' ' -f1`
	if [ -z $(echo "$hostIP" | grep : | grep -v "\.") ] && [ "$IPv6" = "1" ] ; then 
		IPv6=0
		logger -t "???AliDDNS???????????????" "?????????$hostIP ???????????? IPv6 ????????????????????????????????????????????????????????????IPv6??????(??????:ff03:0:0:0:0:0:0:c1)"
		return 1
	fi
	if [ "$hostIP"x = "x"  ] ; then
		curltest=`which curl`
		if [ -z "$curltest" ] || [ ! -s "`which curl`" ] ; then
			[ "$hostIP"x = "x"  ] && hostIP=`wget -T 5 -t 3 --no-check-certificate --quiet --output-document=- "http://members.3322.org/dyndns/getip" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
			[ "$hostIP"x = "x"  ] && hostIP=`wget -T 5 -t 3 --no-check-certificate --quiet --output-document=- "ip.3322.net" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
			[ "$hostIP"x = "x"  ] && hostIP=`wget -T 5 -t 3 --no-check-certificate --quiet --output-document=- "https://www.ipip.net/" | grep "IP??????" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
			[ "$hostIP"x = "x"  ] && hostIP=`wget -T 5 -t 3 --no-check-certificate --quiet --output-document=- "http://pv.sohu.com/cityjson?ie=utf-8" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
		else
			[ "$hostIP"x = "x"  ] && hostIP=`curl -L -k -s "http://members.3322.org/dyndns/getip" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
			[ "$hostIP"x = "x"  ] && hostIP=`curl -L -k -s ip.3322.net | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
			[ "$hostIP"x = "x"  ] && hostIP=`curl -L -k -s "https://www.ipip.net" | grep "IP??????" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
			[ "$hostIP"x = "x"  ] && hostIP=`curl -L -k -s http://pv.sohu.com/cityjson?ie=utf-8 | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
		fi
		if [ "$hostIP"x = "x"  ] ; then
			logger -t "???AliDDNS???????????????" "????????????????????? IP ?????????????????????????????????????????????"
			return 1
		fi
	fi
	echo "Updating Domain: ${2}.${1}"
	echo "hostIP: ${hostIP}"
	lastIP=$(arDdnsInfo "$1 $2")
	if [ $? -eq 1 ]; then
		[ "$IPv6" != "1" ] && lastIP=$(arNslookup "${2}.${1}")
		[ "$IPv6" = "1" ] && lastIP=$(arNslookup6 "${2}.${1}")
	fi
	echo "lastIP: ${lastIP}"
	if [ "$lastIP" != "$hostIP" ] ; then
		logger -t "???AliDDNS???????????????" "???????????? ${2}.${1} ?????? IP ??????"
		logger -t "???AliDDNS???????????????" "?????? IP: ${hostIP}"
		logger -t "???AliDDNS???????????????" "?????? IP: ${lastIP}"
		sleep 1
		postRS=$(arDdnsUpdate $1 $2)
		if [ $? -eq 0 ]; then
			echo "postRS: ${postRS}"
			logger -t "???AliDDNS???????????????" "????????????DNS???????????????"
			return 0
		else
			echo ${postRS}
			logger -t "???AliDDNS???????????????" "????????????DNS???????????????????????????????????????"
			if [ "$IPv6" = "1" ] ; then 
				IPv6=0
				logger -t "???AliDDNS???????????????" "?????????$hostIP ???????????? IPv6 ????????????????????????????????????????????????????????????IPv6??????(??????:ff03:0:0:0:0:0:0:c1)"
				return 1
			fi
			return 1
		fi
	fi
	echo ${lastIP}
	echo "Last IP is the same as current IP!"
	return 1
}


initconfig () {

if [ ! -s "/etc/storage/ddns_script.sh" ] ; then
cat > "/etc/storage/ddns_script.sh" <<-\EEE
# ??????????????????????????????????????????IP??????????????????#?????????
arIpAddress () {
# IPv4????????????
# ??????????????????
curltest=`which curl`
if [ -z "$curltest" ] || [ ! -s "`which curl`" ] ; then
    #wget -T 5 -t 3 --no-check-certificate --quiet --output-document=- "https://www.ipip.net" | grep "IP??????" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
    wget -T 5 -t 3 --no-check-certificate --quiet --output-document=- "http://members.3322.org/dyndns/getip" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
    #wget -T 5 -t 3 --no-check-certificate --quiet --output-document=- "ip.3322.net" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
    #wget -T 5 -t 3 --no-check-certificate --quiet --output-document=- "http://pv.sohu.com/cityjson?ie=utf-8" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
else
    #curl -L -k -s "https://www.ipip.net" | grep "IP??????" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
    curl -L -k -s "http://members.3322.org/dyndns/getip" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
    #curl -L -k -s ip.3322.net | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
    #curl -L -k -s http://pv.sohu.com/cityjson?ie=utf-8 | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
fi
}
arIpAddress6 () {
# IPv6????????????
# ????????????ipv6??????nat ipv6???????????????????????????
ifconfig $(nvram get wan0_ifname_t) | awk '/Global/{print $3}' | awk -F/ '{print $1}'
}
if [ "$IPv6" = "1" ] ; then
arIpAddress=$(arIpAddress6)
else
arIpAddress=$(arIpAddress)
fi
EEE
	chmod 755 "$ddns_script"
fi

}

initconfig

case $ACTION in
start)
	aliddns_close
	aliddns_check
	;;
check)
	aliddns_check
	;;
stop)
	aliddns_close
	;;
keep)
	aliddns_keep
	;;
*)
	aliddns_check
	;;
esac

