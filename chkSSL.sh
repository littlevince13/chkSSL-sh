#!/bin/bash

#Variables
script=${0##/}
exitcode=''
WRITEFILE=0
CONFIG=0
DIR=0

# functions
usage()
{
cat <<EOF

  USAGE: $script -[cdewh]"

  DESCRIPTION: This script predicts the expiring SSL certificates based on the end date.

  OPTIONS:

  -c|   sets the value for configuration file which has server:port or host:port details.

  -d|   sets the value of directory containing the certificate files in crt or pem format.

  -e|   sets the value of certificate extention, e.g crt, pem, cert.
        crt: default

  -w|   sets the value for writing the script output to a file.

  -h|   prints this help and exit.

EOF
exit 1
}
# print info messages
info()
{
  printf '\n%s: %6s\n' "INFO" "$@"
}
# print error messages
error()
{
  printf '\n%s: %6s\n' "ERROR" "$@"
  exit 1
}
# print warning messages
warn()
{
  printf '\n%s: %6s\n' "WARN" "$@"
}
# get expiry for the certificates
getExpiry()
{
  local expdate=$1
  local certname=$2
  today=$(date +%s)
  timetoexpire=$(( ($expdate - $today)/(60*60*24) ))

  expcerts=( ${expcerts[@]} "${certname}:$timetoexpire" )
}

# print all expiry that was found, typically if there is any.
printExpiry()
{
  local args=$#
  i=0
  if [[ $args -ne 0 ]]; then
    #statements
    printf '%s\n' "Subject: List of expiring SSL certificatess"
    printf '%s\n' "---------------------------------------------"
    printf '%s\n' "List of expiring SSL certificates"
    printf '%s\n' "---------------------------------------------"
    printf '%s\n' "$@"  | \
      sort -t':' -g -k2 | \
      column -s: -t     | \
      awk '{printf "%d.\t%s\n", NR, $0}'
    printf '%s\n' "---------------------------------------------"
  fi
}

# calculate the end date for the certificates first, finally to compare and predict when they are going to expire.
calcEndDate()
{
  sslcmd=$(which openssl)
  if [[ x$sslcmd = x ]]; then
    #statements
    error "$sslcmd command not found!"
  fi
  # when cert dir is given
  if [[ $DIR -eq 1 ]]; then
    #statements
    checkcertexists=$(ls -A $TARGETDIR| egrep "*.$EXT$")
    if [[ -z ${checkcertexists} ]]; then
      #statements
      error "no certificate files at $TARGETDIR with extention $EXT"
    fi
    for file in $TARGETDIR/*.${EXT:-crt}
    do
      expdate=$($sslcmd x509 -in $file -noout -enddate)
      expepoch=$(date -d "${expdate##*=}" +%s)
      certificatename=${file##*/}
      getExpiry $expepoch ${certificatename%.*}
    done
  elif [[ $CONFIG -eq 1 ]]; then
    #statements
    while read line
    do
      if echo "$line" | \
      egrep -q '^[a-zA-Z0-9.]+:[0-9]+|^[a-zA-Z0-9]+_.*:[0-9]+';
      then
        expdate=$(echo | \
        openssl s_client -connect $line 2>/dev/null | \
        openssl x509 -noout -enddate 2>/dev/null);
        if [[ $expdate = '' ]]; then
          #statements
          warn "[error:0906D06C] Cannot fetch certificates for $line"
        else
          expepoch=$(date -d "${expdate##*=}" +%s);
          certificatename=${line%:*};
          getExpiry $expepoch ${certificatename};
        fi
      else
        warn "[format error] $line is not in required format!"
      fi
    done < $CONFIGFILE
  fi
}
# your script goes here
while getopts ":c:d:w:e:h" options
do
case $options in
c )
  CONFIG=1
  CONFIGFILE="$OPTARG"
  if [[ ! -e $CONFIGFILE ]] || [[ ! -s $CONFIGFILE ]]; then
    #statements
    error "$CONFIGFILE does not exist or empty!"
  fi
        ;;
e )
  EXT="$OPTARG"
  case $EXT in
    crt|pem|cert )
    info "Extention check complete."
    ;;
    * )
    error "invalid certificate extention $EXT!"
    ;;
  esac
  ;;
d )
  DIR=1
  TARGETDIR="$OPTARG"
  [ $TARGETDIR = '' ] && error "$TARGETDIR empty variable!"
  ;;
w )
  WRITEFILE=1
  OUTFILE="$OPTARG"
  ;;
h )
        usage
        ;;
\? )
        usage
        ;;
: )
        fatal "Argument required !!! see \'-h\' for help"
        ;;
esac
done
shift $(($OPTIND - 1))
#
calcEndDate
#finally print the list
if [[ $WRITEFILE -eq 0 ]]; then
  #statements
  printExpiry ${expcerts[@]}
else
  printExpiry ${expcerts[@]} > $OUTFILE
fi
