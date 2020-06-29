# chkSSL-sh
yum install ssmtp
./chkSSL.sh -c list.txt > email.txt
ssmtp {email} < email.txt
