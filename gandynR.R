#!/usr/bin/Rscript
################################################################################
#
#   GandynR:  Automatic DNS update for Gandi.net hosting.
#               Retrive current public IP of web server and update zone's record.
#               Written in R. Why not...
#               With ssh security check. Sort of :
#                 Need passwordless ssh connection to yourself
#                 to be sure that new ip is yours.
#  
#   2014 f@fxi.io
#  
#       Use at your own risk, i've done this for myself because it's a rainy day.
#       See also for python and/or bash alternative.
#
#   Usage :
#     1. Be sure you can SSH your own server without password. (See Refs below)
#     2. On your web server: copy this script to the 
#         location and name of your choice: 
#         E.g. : ~/gandiDNS/gandynR.R
#     3. Uncomment and complete default config in this script OR 
#         write it in external file (See config block):
#         E.g. : ~/gandiDNS/gandynR-config.R
#     4. set a cron job to launch that script :
#         $ chmod +x ~/gandiDNS/gandynR.R
#         $ crontab -e
#         Add this line (modify with your username and path)
#         */5 * * * * /home/randy/gandiDNS/gandynR.R
# 
#   NOTES :  execute those line in R console to install XML-RPC package
#           > source("http://bioconductor.org/biocLite.R") 
#           > biocLite("XMLRPC")
#
# ref : 
#  -- http://superuser.com/questions/8077/how-do-i-set-up-ssh-so-i-dont-have-to-type-my-password 
#  -- https://github.com/Chralu/gandyn
#  -- http://gerard.geekandfree.org/blog/2012/03/01/debarrassez-vous-de-dyndns-en-utilisant-lapi-de-gandi/
#  -- http://superuser.com/questions/522887/how-can-i-get-my-public-ip-address-from-the-command-line-if-i-am-behind-a-route
#  -- http://doc.rpc.gandi.net/domain/reference.html#domain.zone.info
################################################################################



######################################
#
# Exemple config. Uncomment and/or 
# copy this block to a file 
# and set path in source('path/to/config'), below 
#
######################################

library('XMLRPC')

# # gandi.net api key
# aKey<-'yourApiKey03oinr3508fn5hohoho'

# # domain name
# dName<-'yourDomainName.com'

# # user id (for ssh connection)
# userId = 'RandySmith'

# # ssh port (keep empty for 22)
# sshPort = 12123

# # retrieve ip on :
ipMe<-'http://ipecho.net/plain'

# # time to live
ttlNew=300

# # log directory
logDir<-'.'

# # gandi xmlrpc end points
xrc<-'https://rpc.gandi.net/xmlrpc/'


# # record to filter (as list!)..
# # See your zone version to check wich one are related to provided ip
recordFilter=list(list(type='A',name='@')
                  # more items to filter :
                  #,list(type='XX',name='XX')
)


######################################
#
# source config. 
# Comment this line if no config file 
# are given 
#
######################################

source('~/gandiDNS/gandynR-config.R')

######################################
#
# Save logs
#
######################################

conOutput <- file(file.path(logDir,'gandynRLog.txt'))

sink(conOutput,append=T,type='output')
sink(conOutput,append=T,type='message')

######################################
#
# Get domain, zone and record info
#
######################################

# get domain infos
domainInfo<-xml.rpc(xrc,'domain.info',.args=list(
  apikey=aKey,
  domain=dName
))
# get zone used by domain
zoneId = domainInfo$zone_id


# get active version id
versionId<-xml.rpc(xrc,'domain.zone.info',
                   apikey=aKey,
                   zone_id=as.integer(zoneId)
)$version

######################################
#
# Get list of records, for each filter item
#
######################################

# for each records filter item, get corresponding data
origRecord<-list()
for(r in recordFilter){
  origRecord<-c(
    origRecord,
    list(xml.rpc(xrc,'domain.zone.record.list',
                 apikey=aKey,
                 zone_id=as.integer(zoneId),
                 version_id=versionId,
                 #filter rows
                 opts=r
    )$value)
  )
}

######################################
#
# Get stored IP and actual IP
#
######################################
ipGandi<-origRecord[[1]]$value
ipReal<-scan(file=ipMe,what='character',quiet=T)

# stop if no ip are retrived.
stopifnot(!is.null(ipGandi) | !is.null(ipReal))

######################################
#
#  Update if there is a change
#
######################################
if(!identical(ipGandi,ipReal)){
  message(date(),':','IP has changed. Old:',ipGandi,' New:',ipReal)
  
  ######################################
  # security step : ssh to myself via provided "real ip". 
  ######################################
  
  amImyself<-
    identical(
      system('uname -a'),
      system(paste(
        "ssh",
        if(!is.null(sshPort)){"-p 4579"}else{''},
        paste0(userId,'@',ipReal),
        "-t 'uname -a'"
      )))
  
  stopifnot(amImyself)
  ######################################
  #
  # Create new version (duplicate active)
  #
  ######################################
  #domain.zone.version.new(apikey, zone_id[, version_id=0])
  newVersionId<-xml.rpc(xrc,'domain.zone.version.new',
                        apikey=aKey,
                        zone_id=as.integer(zoneId),
                        version_id=versionId)
  
  newRecord<-origRecord
  #########################################
  # update records of newly created version
  #########################################
  for(i in length(newRecord)){
    nRec<-newRecord[[i]]
    idRec<-nRec$id
    xml.rpc(xrc,'domain.zone.record.update',.args=list(
      apikey=aKey,
      zone_id=as.integer(zoneId),
      version_id=as.integer(newVersionId),
      #filter rows
      opts=list(id=as.integer(idRec)),
      params=list(
        name=nRec$name,
        type=nRec$type,
        value=ipReal,
        ttl=as.integer(ttlNew)))
    )
  }
  
  #########################################
  # SET NEW VERSION AS ACTIVE
  #########################################
  #domain.zone.version.set(apikey, zone_id, version_id)
  activated<-xml.rpc(xrc,'domain.zone.version.set',.args=list(
    apikey=aKey,
    zone_id=as.integer(zoneId),
    version_id=as.integer(newVersionId))
  )
  
  if(activated){
    
    #########################################
    # REMOVE OLD ONE
    #########################################
    
    xml.rpc(xrc,'domain.zone.version.delete',.args=list(
      apikey=aKey,
      zone_id=as.integer(zoneId),
      version_id=as.integer(versionId))
    )
    
  }else{
    warning(date(),': New version not activated ! Returned message:',activated )
    
    #########################################
    # REMOVE NEW ONE
    #########################################
    
    xml.rpc(xrc,'domain.zone.version.delete',.args=list(
      apikey=aKey,
      zone_id=as.integer(zoneId),
      version_id=as.integer(newVersionId))
      )
  }
  
}else{
  message(date(),':','IP not changed. Old:',ipGandi,' New:',ipReal)
}

# restore output to console. 
sink() 
sink(type="message")



######################################
#
# Nothig to do here.
#
######################################




