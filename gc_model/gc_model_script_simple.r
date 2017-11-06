###########################################################################
###########################################################################
############## Created by Heather Kropp in October 2017      ##############
############## This script is to be run for all analyses     ##############
############## of canopy stomatal conductance calculated     ##############
############## from sapflow.                                 ##############
###########################################################################
###########################################################################
############## Input files:                                  ##############
############## from sapflux calc:                            ##############
############## Transpiration: El.L,El.L17,El.H,El.H17        ##############
############## stomatal conductance:gc.L, gc.L17, gc.H, gc.H17#############
############## tree info: datTreeL, datTreeL17, datTreeH,     #############
##############            datTreeH17                          #############
############## from thaw depth:                               #############
##############  TDall: by stand and year                      #############
###########################################################################
###########################################################################


#################################################################
####read in sapflow data                                  #######
#################################################################
source("c:\\Users\\hkropp\\Documents\\GitHub\\larch_density_ecohydro\\sapflux_process.r")
#libraries loaded from source
#plyr, lubridate,caTools
#################################################################
####read in thawdepth data                                #######
#################################################################
source("c:\\Users\\hkropp\\Documents\\GitHub\\larch_density_ecohydro\\thaw_depth_process.r")
# libraries
library(snow)
library(snowfall)
library(coda)
library(mcmcplots)

#################################################################
####indicate if this is a spatial model                   #######
#################################################################
#1 indicates uses coordinates 0 no
spatialmodel <- 1

#################################################################
####specify directories                                   #######
#################################################################
#model output
saveMdir <- c("c:\\Users\\hkropp\\Google Drive\\Viper_Ecohydro\\gc_model\\run16")
#model code
modCode <- "c:\\Users\\hkropp\\Documents\\GitHub\\larch_density_ecohydro\\gc_model\\gc_model_code_simple.r"



#################################################################
####read in datafiles                                     #######
#################################################################

# airport pressure and precip data
datAirP <- read.csv("c:\\Users\\hkropp\\Google Drive\\viperSensor\\airport\\airport.csv")

#canopy rh and temperature
datRH <- read.csv("c:\\Users\\hkropp\\Google Drive\\viperSensor\\met\\RH.VP4.csv")
datTC <- read.csv("c:\\Users\\hkropp\\Google Drive\\viperSensor\\met\\TempC.VP4.csv")

#PAR
datPAR <- read.csv("c:\\Users\\hkropp\\Google Drive\\viperSensor\\met\\PAR.QSOS PAR.csv")

#tree coordinates
datTcoor <- read.csv("c:\\Users\\hkropp\\Google Drive\\Viper_Ecohydro\\individual_data\\tree_coord_out.csv")

#tree neighbor distance and density
datLdist <- read.csv("c:\\Users\\hkropp\\Google Drive\\Viper_Ecohydro\\individual_data\\ld_near.csv")
datHdens <- read.csv("c:\\Users\\hkropp\\Google Drive\\Viper_Ecohydro\\individual_data\\hd_neighbor.csv")

#################################################################
####organize met data                                     #######
#################################################################
#subset and match
datLRHmet <- data.frame(datRH[datRH$site=="ld",1:3], RH=datRH$RH.VP4[datRH$site=="ld"])
datLTCmet <- data.frame(datTC[datTC$site=="ld",1:3], Temp=datTC$TempC.VP4[datTC$site=="ld"])

datHRHmet <- data.frame(datRH[datRH$site=="hd",1:3], RH=datRH$RH.VP4[datRH$site=="hd"])
datHTCmet <- data.frame(datTC[datTC$site=="hd",1:3], Temp=datTC$TempC.VP4[datTC$site=="hd"])
#join temp and RH
datLmet <- join(datLRHmet, datLTCmet, by=c("doy","year","hour"),type="inner")
datHmet <- join(datHRHmet, datHTCmet, by=c("doy","year","hour"),type="inner")

#join into gc tables
datgcL <- join(gc.L,datLmet, by=c("doy","year","hour"), type="left")
datgcH <- join(gc.H,datHmet, by=c("doy","year","hour"), type="left")
datgcL17 <- join(gc.L17,datLmet, by=c("doy","year","hour"), type="left")
datgcH17 <- join(gc.H17,datHmet, by=c("doy","year","hour"), type="left")

######calculate VPD##########
#calculate saturated vapor pressure
datLe.sat<-0.611*exp((17.502*datgcL$Temp)/(datgcL$Temp+240.97))
datLe.sat17<-0.611*exp((17.502*datgcL17$Temp)/(datgcL17$Temp+240.97))
datHe.sat17<-0.611*exp((17.502*datgcH17$Temp)/(datgcH17$Temp+240.97))
datHe.sat<-0.611*exp((17.502*datgcH$Temp)/(datgcH$Temp+240.97))

#calculate vapor pressure deficit
#here rh is is in decimal form 
datgcL$RHfix<-ifelse(datgcL$RH>=1,.999,datgcL$RH)
datgcL17$RHfix<-ifelse(datgcL17$RH>=1,.999,datgcL17$RH)
datgcH$RHfix<-ifelse(datgcH$RH>=1,.999,datgcH$RH)
datgcH17$RHfix<-ifelse(datgcH17$RH>=1,.999,datgcH17$RH)

#vpd
datgcL$D<-(datLe.sat-(datgcL$RHfix*datLe.sat))
datgcL17$D<-(datLe.sat17-(datgcL17$RHfix*datLe.sat17))
datgcH17$D<-(datHe.sat17-(datgcH17$RHfix*datHe.sat17))
datgcH$D<-(datHe.sat-(datgcH$RHfix*datHe.sat))

#join PAR to the dataframes
datPARL <- data.frame(doy=datPAR$doy[datPAR$site=="ld"], year=datPAR$year[datPAR$site=="ld"],
						hour=datPAR$hour[datPAR$site=="ld"], PAR=datPAR$PAR.QSOS.Par[datPAR$site=="ld"])
datPARH <- data.frame(doy=datPAR$doy[datPAR$site=="hd"], year=datPAR$year[datPAR$site=="hd"],
						hour=datPAR$hour[datPAR$site=="hd"], PAR=datPAR$PAR.QSOS.Par[datPAR$site=="hd"])						
#join PAR to gc
datgcL <- join(datgcL, datPARL, by=c("doy", "year","hour"), type="inner")						
datgcL17 <- join(datgcL17, datPARL, by=c("doy", "year","hour"), type="inner")					
datgcH <- join(datgcH, datPARH, by=c("doy", "year","hour"), type="inner")
datgcH17 <- join(datgcH17, datPARH, by=c("doy", "year","hour"), type="inner")

#join precip data to check for filtering
datPrecip <- data.frame(doy=datAirP$doy, year=datAirP$year,Pr.mm = datAirP$Pr.mm)

datgcL <- join(datgcL, datPrecip, by=c("doy", "year"), type="left")						
datgcL17 <- join(datgcL17, datPrecip, by=c("doy", "year"), type="left")					
datgcH <- join(datgcH, datPrecip, by=c("doy", "year"), type="left")
datgcH17 <- join(datgcH17, datPrecip, by=c("doy", "year"), type="left")

#################################################################
####gc filter                                             #######
#################################################################
#light more than 5 umol m-2 s-1 (to exclude nocturnal measurements that may include refilling)
#D>= 0.6kPA (per Ewers and Oren 2000)
#precip more than 1mm

m.gcL <- datgcL[datgcL$D>=.6&datgcL$PAR>5&datgcL$Pr.mm<=1,]
m.gcL17 <- datgcL17[datgcL17$D>=.6&datgcL17$PAR>5&datgcL17$Pr.mm<=1,]
m.gcH <- datgcH[datgcH$D>=.6&datgcH$PAR>5&datgcH$Pr.mm<=1,]
m.gcH17 <- datgcH17[datgcH17$D>=.6&datgcH17$PAR>5&datgcH17$Pr.mm<=1,]


#################################################################
####organize data for model                               #######
#################################################################
#stand ID 1=low density, 2=high density
#organize the data by sensor and stand
#and omit missing sensor measurements
tgcL <- list()
for(i in 1:dim(datTreeL)[1]){
	tgcL[[i]] <- na.omit(data.frame(doy=m.gcL$doy, 
					year=m.gcL$year, hour=m.gcL$hour,
					g.c=m.gcL[,i+3], D=m.gcL$D,PAR=m.gcL$PAR,treeID.new=rep(datTreeL$treeID.new[i], dim(m.gcL)[1]),
					stand=rep(1, dim(m.gcL)[1])))
}

tgcL17 <- list()
for(i in 1:dim(datTreeL17)[1]){
	tgcL17[[i]] <- na.omit(data.frame(doy=m.gcL17$doy, 
					year=m.gcL17$year, hour=m.gcL17$hour,
					g.c=m.gcL17[,i+3], D=m.gcL17$D,PAR=m.gcL17$PAR,treeID.new=rep(datTreeL17$treeID.new[i], dim(m.gcL17)[1]),
					stand=rep(1, dim(m.gcL17)[1])))
}

tgcH <- list()
for(i in 1:dim(datTreeH)[1]){
	tgcH[[i]] <- na.omit(data.frame(doy=m.gcH$doy, 
					year=m.gcH$year, hour=m.gcH$hour,
					g.c=m.gcH[,i+3], D=m.gcH$D,PAR=m.gcH$PAR,treeID.new=rep(datTreeH$treeID.new[i], dim(m.gcH)[1]),
					stand=rep(2, dim(m.gcH)[1])))
}
tgcH17 <- list()
for(i in 1:dim(datTreeH17)[1]){
	tgcH17[[i]] <- na.omit(data.frame(doy=m.gcH17$doy, 
					year=m.gcH17$year, hour=m.gcH17$hour,
					g.c=m.gcH17[,i+3], D=m.gcH17$D,PAR=m.gcH17$PAR,treeID.new=rep(datTreeH17$treeID.new[i], dim(m.gcH17)[1]),
					stand=rep(2, dim(m.gcH17)[1])))
}


#now turn into single data frame
lowGC <-ldply(tgcL, data.frame)
lowGC17 <-ldply(tgcL17, data.frame)
highGC <-ldply(tgcH, data.frame)
highGC17 <-ldply(tgcH17, data.frame)

gcALL <- rbind(lowGC,lowGC17,highGC,highGC17)

#################################################
#################################################
##JUST for SPATIAL MODEL!!!!!!!!!!!!!! ##########
#################################################
#################################################
#exclude non repeat tree from low density 2016 
#since no spatial reference for it
if(spatialmodel==1){
	gcALL <- gcALL[gcALL$treeID.new<14,]

}




#first check how many tree X day X stand observations there are
nCheck1 <- aggregate(gcALL$g.c, by=list(gcALL$doy,gcALL$year, gcALL$stand, gcALL$treeID.new), FUN="length")
#check that there are at least multiple trees present in each day
nCheck2 <- aggregate(nCheck1$x, by=list(nCheck1$Group.1,nCheck1$Group.2,nCheck1$Group.3), FUN="length")
#check that there are how many measurements that are in each day
nCheck3 <- aggregate(gcALL$g.c, by=list(gcALL$doy,gcALL$year, gcALL$stand), FUN="length")
#this check is a better filter, because as long at there are at least 15 measurements the day is reasonable
colnames(nCheck3) <- c("doy", "year", "stand", "count") 

nCheck3 <- nCheck3[nCheck3$count>=15,]
#now filter days that don't have at least 15 observations out
nfilter <- nCheck3[,1:3]

gcALLf <- join(gcALL, nfilter, by=c("doy", "year", "stand"), type="inner")

#get unique combinations to generate IDS
#standDayIDS
standDay <- unique(data.frame(doy=gcALLf$doy,year=gcALLf$year,stand=gcALLf$stand))
standDay$standDay <-seq(1, dim(standDay)[1])

#join back into gcAll
gcALL2 <- join(gcALLf, standDay, by=c("doy", "year", "stand"), type="left")

#get average daily temperature for a covariate
TairH <- aggregate(datHmet$Temp, by=list(datHmet$doy,datHmet$year), FUN="mean")
colnames(TairH) <- c("doy","year","Tair")
TairH$stand <- rep(2, dim(TairH)[1])

TairL <- aggregate(datLmet$Temp, by=list(datLmet$doy,datLmet$year), FUN="mean")
colnames(TairL) <- c("doy","year","Tair")
TairL$stand <- rep(1, dim(TairL)[1])

Tair <- rbind(TairH, TairL)

#add air temp into the stand day da
standDay2 <- join(standDay,Tair, by=c("doy","year", "stand"), type="left")

#get 

#subset to get unique days
Days <- unique(data.frame(doy=standDay2$doy,year=standDay2$year))
Days <- Days[order(Days$year,Days$doy ),]
Days$Days <- seq(1, dim(Days)[1])

#take averages over previous 2 weeks
#now make a precip matrix that includes days into the past
precipmat <- matrix(rep(NA, dim(Days)[1]*14), ncol=14)

for(i in 1:dim(Days)[1]){
	for(j in 1:14){
		precipmat[i,j] <- datAirP$Pr.mm[datAirP$doy==(Days$doy[i]-j)&datAirP$year==Days$year[i]]
	
	}
}

precipDF <- data.frame(doy=Days$doy,Days=Days$Days, year=Days$year,precipAve = rowMeans(precipmat))

standDay3 <- join(standDay2, precipDF, by=c("doy","year"), type="left")

#match up thaw depth data
#create a stand ID in thaw depth
#take only relevant TD cols
#TDall needs 2 more days for hd 2016
TDchange <- TDall$TDday[TDall$year==2016&TDall$site=="hd"&TDall$doy==185]-TDall$TDday[TDall$year==2016&TDall$site=="hd"&TDall$doy==184]
TDtemp <- data.frame(doy=c(182,183), year=c(2016,2016), site=c("hd","hd"), TD=c(NA,NA),
		TDday=c(TDall$TDday[TDall$year==2016&TDall$site=="hd"&TDall$doy==184]-(TDchange*2),
			TDall$TDday[TDall$year==2016&TDall$site=="hd"&TDall$doy==184]-TDchange))
TDall <- rbind(TDtemp,TDall)


TDsub <- data.frame(doy =TDall$doy, year= TDall$year, stand = ifelse(TDall$site=="hd",2,1),TD=TDall$TDday)

#join in stand day
standDay4 <- join(standDay3, TDsub, by=c("doy","year","stand"), type="left")

#variables for centering
#air temp
airTmean<- mean(standDay2$Tair)
#thaw depth minimum
TDstart <- aggregate(standDay4$TD, by=list(standDay4$stand), FUN="min")
colnames(TDstart) <- c("stand", "TD")
TDstart$TD <- floor(TDstart$TD)

#aggregate
gcALL3p1 <- aggregate(gcALL2$g.c, by=list(gcALL2$doy,gcALL2$year,gcALL2$hour,gcALL2$stand,gcALL2$standDay),FUN="mean")
gcALL3p2 <- aggregate(gcALL2$D, by=list(gcALL2$doy,gcALL2$year,gcALL2$hour,gcALL2$stand,gcALL2$standDay),FUN="mean")
gcALL3p3 <- aggregate(gcALL2$PAR, by=list(gcALL2$doy,gcALL2$year,gcALL2$hour,gcALL2$stand,gcALL2$standDay),FUN="mean")
colnames(gcALL3p1) <- c("doy","year","hour","stand","standDay","g.c")
colnames(gcALL3p2) <- c("doy","year","hour","stand","standDay","D")
colnames(gcALL3p3) <- c("doy","year","hour","stand","standDay","PAR")

gcALL3p4 <- join(gcALL3p1,gcALL3p2, by=c("doy","year","hour","stand","standDay"), type="full")
gcALL3 <- join(gcALL3p4,gcALL3p3, by=c("doy","year","hour","stand","standDay"), type="full")



#################################################################
####model run                                             #######
#################################################################
#try running  model without stochastic antecedent precip in JAGS and with all variables

#new data stand.obs, NstandDayTree, standDayTree, stand, tree, N tree, thawD, thawstart(stand), Nstand, xC[i,y] DistA=sqrt(pow(xC[y]-xC[m],2)+ pow(y[r] - y[c], 2))
#data list

datalist <- list(Nobs=dim(gcALL3)[1], gs=gcALL3$g.c, stand.obs=gcALL3$stand, standDay=gcALL3$standDay,
					PAR=gcALL3$PAR,
					D=gcALL3$D, NstandDay=dim(standDay4)[1],
					stand=standDay4$stand, airT=standDay4$Tair,
					airTmean=airTmean,pastpr=standDay4$precipAve,
					thawD=standDay4$TD, thawstart=TDstart$TD, 
					 Nstand=2)

# set parameters to monitor
parms <-c( "a1", "a2", "a3", "b1", "b2", "b3",  "gref", "S", "d1","d2","d3","a4",
				"b4","d4","l.slope","rep.gs")

# set the number of CPUs to be 3
sfInit(parallel=TRUE, cpus=3)

# assign the R2OpenBUGS library to each CPU
sfLibrary(R2OpenBUGS)	


#creating separate directory for each CPU process
folder1 <- paste0(saveMdir, "\\chain1")
folder2 <- paste0(saveMdir, "\\chain2")
folder3 <- paste0(saveMdir, "\\chain3")
dir.create(folder1); dir.create(folder2); dir.create(folder3)	
folderALL <- c(folder1, folder2, folder3)
#copy model code
for (i in 1:length(folderALL)){

	file.copy(modCode, paste0(folderALL[i], "\\model_code.txt"), overwrite=TRUE) 

}	

#get model started but run manually
parallel.bugs <- function(chain, x.data, params){
	folder <- ifelse(chain==1,"c:\\Users\\hkropp\\Google Drive\\Viper_Ecohydro\\gc_model\\run16\\chain1",
				ifelse(chain==2,"c:\\Users\\hkropp\\Google Drive\\Viper_Ecohydro\\gc_model\\run16\\chain2",
					"c:\\Users\\hkropp\\Google Drive\\Viper_Ecohydro\\gc_model\\run16\\chain3"))
 	
	inits <- ifelse(chain==1,source("c:\\Users\\hkropp\\Google Drive\\Viper_Ecohydro\\gc_model\\run16\\chain1\\inits.R"),
				ifelse(chain==2,source("c:\\Users\\hkropp\\Google Drive\\Viper_Ecohydro\\gc_model\\run16\\chain2\\inits.R"),
					source("c:\\Users\\hkropp\\Google Drive\\Viper_Ecohydro\\gc_model\\run16\\chain3\\inits.R")))
	
	# 5b. call openbugs
	bugs(data=x.data,inits=inits, parameters.to.save=params,
             n.iter=10, n.chains=1, n.burnin=1, n.thin=1,
             model.file="model_code.txt", codaPkg=TRUE,
             OpenBUGS.pgm="C:/Program Files (x86)/OpenBUGS/OpenBUGS323/OpenBUGS.exe",debug=TRUE,
             working.directory=folder)	
}			 


# parallel.bugs on each of the 3 CPUs
sfLapply(1:3, fun=parallel.bugs,x.data=datalist, params=parms)
#after the small number of iterations runs, I make sure it uses a slice updater, run for a test of 11 samples,
#and then I update thinning every 25.


folder1 <- paste0(saveMdir, "\\CODA_out\\chain1\\")
folder2 <- paste0(saveMdir, "\\CODA_out\\chain2\\")
folder3 <- paste0(saveMdir, "\\CODA_out\\chain3\\")




# 9. pull coda back out
codaobj1 <- read.bugs(c(paste0(folder1, "\\CODAchain1.txt"),
						paste0(folder2, "\\CODAchain1.txt")
						,paste0(folder3, "\\CODAchain1.txt")
						))


mcmcplot(codaobj1,, parms=c( "a1", "a2", "a3", "b1", "b2", "b3",  "gref", "S", "d1","d2","d3","a4",
				"b4","d4","l.slope"),  dir=paste0(saveMdir, "\\history"))



modSum <-summary(codaobj1) 


write.table(modSum$statistics, paste0(saveMdir, "\\out", "\\mod_stats.csv"), sep=",", row.names=TRUE)
write.table(modSum$quantiles, paste0(saveMdir, "\\out", "\\mod_quants.csv"), sep=",", row.names=TRUE)
write.table(standDay4, paste0(saveMdir, "\\out", "\\standDay.csv"), sep=",", row.names=FALSE)
write.table(gcALL3, paste0(saveMdir, "\\out", "\\gcdata.csv"), sep=",", row.names=FALSE)
#aggregate to compare means