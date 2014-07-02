
GandynR (test version)
=======

### Automatic DNS update for Gandi.net hosting. With R. And ssh.

* Before reading this, check first [gandyn](https://github.com/Chralu/gandyn) : nice and working python script.
* So, why coding a new script if [gandyn](https://github.com/Chralu/gandyn) works well ?
* Personal learning + rainy day. And to see if it was possible to do this with `R`. And also :
* Adding small security check. Sort of : try a ssh connection to itself to check new retrieved IP.
* A bit more minimalistic. Dumber ?
* If something goes wrong, nothing is done, logs are written in one file.
* Clean readable output, from my point of view :

```{sh}
randy@rpi ~/gandynR $ cat gandynR-log.txt
Wed Jul  2 19:40:25 2014:IP not changed. Old:101.62.189.138 New:101.62.189.138
Wed Jul  2 19:44:45 2014:IP not changed. Old:101.62.189.138 New:101.62.189.138
Wed Jul  2 19:50:44 2014:IP has changed. Old:101.62.189.138 New:101.62.189.139
```

### to do :
* testing
* adding external mail warning support with `sendMailR`


### Prequisites
* Make a backup of your zone versions before using this script.
* Be sure you can SSH your own server from itself without password. (See Refs below)
* Enable XML-RPC interface for your domain on [gandi](https://gandi.net) and get an API key.
* Install R library `XMLRPC`. In a `R` console :

```{r}
source("http://bioconductor.org/biocLite.R") 
biocLite("XMLRPC")
```

* Clone `gandynR` git project somewhere on your web server: `git clone https://github.com/fxi/gandynR.git` 
* Rename `gandynR-config.exemple.R` to `gandynR-config.R` and complete it with these `R` lines :

```{r}
aKey <- 'yourApiKey03oinr3508fn5hohoho' # your personal gandi api key
dName <- 'yourDomainName.com' # your domain name
userId <- 'Randy' # ssh user id
sshPort <- '12123' # default ssh port is 22
logDir <- '~/myGandynR/' # directory where to write messages AND outputs.
```
* try it : /usr/bin/Rscript /pathTo/gandynR.R /pathTo/configDir/
* Set a cron action :
  * `crontab -e`
  * Add this line :
  
```{sh}
*/5 * * * * /usr/bin/Rscript /pathTo/gandynR.R /pathTo/gandynR-config.R
```

### reference
1. [ssh passwordless / superuser.com](http://superuser.com/questions/8077/how-do-i-set-up-ssh-so-i-dont-have-to-type-my-password )
2. [original gandyn script](https://github.com/Chralu/gandyn) 
3. [hipster script, before gandyn was cool](http://gerard.geekandfree.org/blog/2012/03/01/debarrassez-vous-de-dyndns-en-utilisant-lapi-de-gandi/)
4. [get public IP / superuser.com]( http://superuser.com/questions/522887/how-can-i-get-my-public-ip-address-from-the-command-line-if-i-am-behind-a-route)
5. [gandi api references](http://doc.rpc.gandi.net/domain/reference.html#domain.zone.info)
6. [XMLRPC / bioconductor](http://bioconductor.org/packages/release/extra/html/XMLRPC.html)
