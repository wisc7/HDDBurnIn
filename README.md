# HDDBurnIn

a script to run a burn in for a new hdd,
runs 
 smartctl -t short
then
  smartctl -t long
then
 checks for bad blocks
then
 does a fio stress test

 Usage:
 edit the runtime options in the script for the tests you want to run (recomend all true)

 then run the command:
 nohup ./HDDBurnin.sh > /var/log/HDDBurninmaster.log 2>&1 &

you can check the progress of the short/long smartctl by running
smartctl -c /dev/sd

you can view the outputs of the smartctl short/long by running
  smartctl -a /dev/sda

bad block checks will be in (by default) 
/var/log/drive_burnin/<drive>_badblocks.log

fio results will be located in 
/var/log/drive_burnin/<drive>_fio.log

 the test can take a few day to run fully and depend on drive size.

 hdd tempratures are monitored thoughout the process and the process will terminate if the drives get critically hot (55 by default - configurable depending on your drives)
