#!/bin/sh

set -e

set_hostname() {
	echo -n "Setting hostname \"${3}\"..."
	resp=
	resp=`curl -sL "https://support.pavietnam.vn/dyndns.php?domain=${1}&token=${2}&host=${3}&ip=${4}"`
	code=$?
	if [ ${code} -ne 0 ]; then
		echo "Failed!"
		return ${code}
	elif [ "${resp}" != "200" ]; then
		if [ "${verbose}" = "1" ]; then
			echo "Error (${resp})!"
		else
			echo "Error!"
		fi
		return 1
	fi
	echo "Done!"
	return 0
}

gen_token() {
	# Token format: <header><API key><hashed timestamp>
	# All hashing processes use MD5 method
	# The construction of hashed timestamp:
	#     T=MD5('<current YYYY-mm-dd HH:MM:SS><random between 10000-99999>')
	# The construction of the header:
	#     H=MD5(MD5('@padyndns<API key>@padyndns' + MD5(T + '<API key>')))
	# The API key does not need to be hashed when inserting into the token string.
	now=`date -u +"%Y-%m-%d %H:%M:%S"`
	rand=`shuf -i 10000-99999 -n 1`
	timestamp=`echo -n ${now}${rand} | md5sum -t | awk '{print \$1}'`
	otp=`echo -n ${timestamp}${1} | md5sum -t | awk '{print \$1}'`
	header1=`echo -n "@padyndns${1}@padyndns${otp}" | md5sum -t | awk '{print \$1}'`
	header2=`echo -n ${header1} | md5sum -t | awk '{print \$1}'`
	echo -n ${header2}${1}${timestamp}
	return 0
}

test_token() {
	echo -n "Testing API key..."
	resp=`curl -sL "https://support.pavietnam.vn/dyndns_check.php?domain=${1}&token=${2}"`
	code=$?
	if [ ${code} -ne 0 ]; then
		echo "Failed!"
		return ${code}
	elif [ "$resp" != "200" ]; then
		if [ "${verbose}" = "1" ]; then
			echo "Invalid (${resp})!"
		else
			echo "Invalid!"
		fi
		return 1
	fi
	echo "OK!"
	return 0
}

exit_handler() {
	if [ $1 -ne 0 ]; then
		exit $1
	elif [ "$2" = "final" ]; then
		exit 0
	fi
	return 0
}

if [ $# -lt 1 ]; then
	echo "Usage: $0 <full-path-to-cred-file> [hostname]"
	echo "Passing hostname will override hostname(s) in credential file."
	echo "Credential file layout (no leading or trailing spaces):"
	echo " domain=<domain registered for dynamic DNS>"
	echo " apikey=<API key of the service>"
	echo " hostname=(\"<hostname to update ip>\" \"<another hostname if any>\")"
	echo " ipcheck_url=[url for getting public IP (optional)]"
	exit 1
fi

env=
if [ -f "$1" ]; then
	env="$1"
fi
source "${env}"

host=
if [ $# -gt 1 ]; then
	host=$2
fi

token=`gen_token ${apikey}`
test_token ${domain} ${token}
exit_handler $?

echo -n "Public IP: "
ip=`curl -sL ${ipcheck_url:-"http://dyn.pavietnam.net/cache/ip.php"}`
ipcode=$?
if [ ${ipcode} -ne 0 ]; then
	echo "<Failed>"
	exit ${ipcode}
elif [[ "${ip}" =~ ^[0-9.]{3,}$ ]]; then
	echo "${ip}"
else
	if [ "${verbose}" = "1" ]; then
		echo "<Invalid (${ip})>"
	else
		echo "<Invalid>"
	fi
	exit 1
fi

if [ "${host}" != "" ]; then
	set_hostname ${domain} ${token} ${host} ${ip}
	exit_handler $?
else
	for host in ${hostname[@]}; do
		set_hostname ${domain} ${token} ${host} ${ip}
		exit_handler $?
	done
fi
exit 0
