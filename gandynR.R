#!/usr/bin/Rscript


######################################
#
# gandynR : update gandi dns with R..
# f@fxi.io
# usage and parameters : see README file
#
######################################

######################################
#
# Internal configuration. 
#
######################################
library(methods)
# # name of config file to search for
configFileName='gandynR-config.R'

# # retrieve ip on :
ipMe<-'http://ipecho.net/plain'

# # time to live
ttlNew=300

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
# source config : first agument given
#   is the config DIRECTORY path
#
######################################
confDir <- commandArgs(trailingOnly = TRUE)[1]
confFile <-path.expand(file.path(confDir,configFileName))
if(!file.exists(confFile)){
  stop(paste(confFile,' : File not found'))
}

testConfig<-try(source(confFile))
if('try-error' %in% class(testConfig)){
  stop(paste('Error produced when reading configFile',testConfig))
}


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




