###########################################################################
###########################################################################
############## Created by Heather Kropp in October 2017      ##############
############## This script creates figures for all time      ##############
############## series data.                                  ##############
###########################################################################
###########################################################################
############## Input files:                                  ##############
############## from sapflux calc:                            ##############
############## Transpiration: El.L,El.L17,El.H,El.H17        ##############
############## stomatal conductance:gc.L, gc.L17, gc.H, gc.H17#############
############## tree info: datTreeL, datTreeL17, datTreeH,     #############
##############            datTreeH17                          #############
##############  from thaw depth: TDall                        #############
###########################################################################


#set the plotting directory
plotDI <- "c:\\Users\\hkropp\\Google Drive\\Viper_Ecohydro\\time_plot"

#################################################################
####read in sapflow data                                  #######
#################################################################
source("c:\\Users\\hkropp\\Documents\\GitHub\\larch_density_ecohydro\\sapflux_process.r")
#libraries loaded from source
#plyr, lubridate,caTools


#################################################################
####read in thaw depth data                               #######
#################################################################

source("c:\\Users\\hkropp\\Documents\\GitHub\\larch_density_ecohydro\\thaw_depth_process.r")

#################################################################
####read in datafiles                                     #######
#################################################################

#read in precip data
datAirP <- read.csv("c:\\Users\\hkropp\\Google Drive\\viperSensor\\airport\\airport.csv")

#read in continuous soil data
datSW <- read.csv("c:\\Users\\hkropp\\Google Drive\\viperSensor\\soil\\vwc.GS3.csv")

#canopy rh and temperature
datRH <- read.csv("c:\\Users\\hkropp\\Google Drive\\viperSensor\\met\\RH.VP4.csv")
datTC <- read.csv("c:\\Users\\hkropp\\Google Drive\\viperSensor\\met\\TempC.VP4.csv")

#PAR
datPAR <- read.csv("c:\\Users\\hkropp\\Google Drive\\viperSensor\\met\\PAR.QSOS PAR.csv")

#################################################################
####calculate daily transpiration                         #######
#################################################################


#El is in g m-2 s-1

#convert to g m-2 half hour-1
#and reorganize
E.temp <- list(El.L,El.L17,El.H,El.H17)
E.dim <- numeric(0)
E.temp2 <- list()
E.temp3 <- list()
for(i in 1:4){
	E.dim[i] <- dim(E.temp[[i]])[2]
	E.temp2[[i]] <- data.frame(E.temp[[i]][,1:3], E.temp[[i]][,4:E.dim[i]]*60*30)
	E.temp3[[i]] <- data.frame(doy=rep(E.temp2[[i]]$doy,times=E.dim[i]-3),
								year=rep(E.temp2[[i]]$year,times=E.dim[i]-3),
								hour=rep(E.temp2[[i]]$hour,times=E.dim[i]-3),
								E.hh = as.vector(data.matrix(E.temp2[[i]][,4:E.dim[i]])),
								tree = rep(seq(1,E.dim[i]-3), each=dim(E.temp2[[i]])[1]))
	E.temp3[[i]] <- na.omit(E.temp3[[i]])
}

#now aggregate to see how many observations in a day
#and pull out data on days that have at least 3 trees
#and those trees have all 48 measurements in a day
ELength <- list()
EdayL <- list()
E.temp4 <- list()
for(i in 1:4){
	ELength[[i]] <- aggregate(E.temp3[[i]]$E.hh, by=list(E.temp3[[i]]$doy,E.temp3[[i]]$year,E.temp3[[i]]$tree),
								FUN="length")
	ELength[[i]] <- ELength[[i]][ELength[[i]]$x==48,]
	colnames(ELength[[i]]) <- c("doy","year","tree","count")
	#find out how many tree observations on each day
	EdayL[[i]] <- aggregate(ELength[[i]]$tree, by=list(ELength[[i]]$doy,ELength[[i]]$year), FUN="length")
	colnames(EdayL[[i]])<- c("doy","year", "ntree")
	#subset to only use days with at least 3 trees
	EdayL[[i]] <- EdayL[[i]][EdayL[[i]]$ntree>=3,]
	#join to only include days with enough sensors
	ELength[[i]] <- join(ELength[[i]],EdayL[[i]], by=c("doy","year"), type="inner")
	#create a tree, day id
	ELength[[i]]$treeDay <- seq(1, dim(ELength[[i]])[1])
	ELength[[i]]$dataset <- rep(i, dim(ELength[[i]])[1])
	#ELength now has the list of each sensor and day that should be included
	#subset the data to only do the calculations on the trees that meet the minimum criteria
	E.temp4[[i]] <- join(E.temp3[[i]],ELength[[i]], by=c("doy", "year", "tree"), type="inner")
}
#turn back into a dataframe
EtempALL <- ldply(E.temp4,data.frame)
EInfo <- ldply(ELength,data.frame)


#get the daily integration of the transpiration
EdayT <- numeric(0)
EdayTemp <- list()
for(i in 1:dim(EInfo)[1]){
	EdayTemp[[i]] <- data.frame(x=EtempALL$hour[EtempALL$treeDay==EInfo$treeDay[i]&EtempALL$dataset==EInfo$dataset[i]],
								y=EtempALL$E.hh[EtempALL$treeDay==EInfo$treeDay[i]&EtempALL$dataset==EInfo$dataset[i]])
	EdayT[i] <- trapz(EdayTemp[[i]]$x,EdayTemp[[i]]$y)

}
#add daily value into Einfo
EInfo$T.day <- EdayT
#in g per day now
EInfo$T.Lday <- EdayT/1000

#add stand labels to the datasets 
EInfo$stand <- ifelse(EInfo$dataset==1|EInfo$dataset==2,"ld","hd")

#get the stand averages of daily transpiration across day

EdayLm <- aggregate(EInfo$T.Lday, by=list(EInfo$doy,EInfo$year,EInfo$stand), FUN="mean")
EdayLsd <- aggregate(EInfo$T.Lday, by=list(EInfo$doy,EInfo$year,EInfo$stand), FUN="sd")
EdayLl <- aggregate(EInfo$T.Lday, by=list(EInfo$doy,EInfo$year,EInfo$stand), FUN="length")

Eday <- EdayLm
colnames(Eday) <- c("doy","year","site","T.L.day")
Eday$T.sd <- EdayLsd$x
Eday$T.n <- EdayLl$x

Eday$T.se <- Eday$T.sd/sqrt(Eday$T.n)



#################################################################
####calculate gc daily values across all tree             #######
#################################################################

#reoranize into data frames
gctemp <- list(gc.L, gc.L17, gc.H, gc.H17)

gcdim <- numeric(0)
gctemp2 <- list()

for(i in 1:4){
	gcdim[i] <- dim(gctemp[[i]])[2]
	gctemp2[[i]] <- data.frame(doy=rep(gctemp[[i]]$doy,times=gcdim[i]-3),
								year=rep(gctemp[[i]]$year,times=gcdim[i]-3),
								hour=rep(gctemp[[i]]$hour,times=gcdim[i]-3),
								gc.h = as.vector(data.matrix(gctemp[[i]][,4:gcdim[i]])),
								tree = rep(seq(1,gcdim[i]-3), each=dim(gctemp[[i]])[1]),
								datset=rep(i, each=dim(gctemp[[i]])[1]) )
	gctemp2[[i]] <- na.omit(gctemp2[[i]])
}
gctemp3 <- ldply(gctemp2, data.frame)

#check that there aren't days with too few observations
gclength <- list()
gcLday1 <- list()
gcLday2 <- list()
for(i in 1:4){
	#how many observations in days and trees
	gclength[[i]] <- aggregate(gctemp2[[i]]$gc.h, by=list(gctemp2[[i]]$doy,gctemp2[[i]]$year,gctemp2[[i]]$tree), FUN="length")
	#subset to exclude trees that only have one obs in a day
	gclength[[i]] <- gclength[[i]][gclength[[i]]$x>3,]
	#how many trees in days
	gcLday1[[i]] <- aggregate(gclength[[i]]$Group.3, by=list(gclength[[i]]$Group.1,gclength[[i]]$Group.2),FUN="length")
		
}
# alot of observations so no need to subset more
#get the average daily gc across all trees


	gsDave <- aggregate(gctemp3$gc.h, by=list(gctemp3$doy,gctemp3$year,gctemp3$datset), FUN="mean")
	gsDsd <- aggregate(gctemp3$gc.h, by=list(gctemp3$doy,gctemp3$year,gctemp3$datset), FUN="sd")
	gsDn <- aggregate(gctemp3$gc.h, by=list(gctemp3$doy,gctemp3$year,gctemp3$datset), FUN="length")
	
	colnames(gsDave) <- c("doy", "year", "dataset","gc.mmol.s")
	gsDave$gc.sd <- gsDsd$x
	gsDave$gc.n <- gsDn$x
	gsDave$gc.se <- gsDave$gc.sd/sqrt(gsDave$gc.n)
	
	gsHHave <- aggregate(gctemp3$gc.h, by=list(gctemp3$hour,gctemp3$doy,gctemp3$year,gctemp3$datset), FUN="mean")
	gsHHsd <- aggregate(gctemp3$gc.h, by=list(gctemp3$hour,gctemp3$doy,gctemp3$year,gctemp3$datset), FUN="sd")
	gsHHn <- aggregate(gctemp3$gc.h, by=list(gctemp3$hour,gctemp3$doy,gctemp3$year,gctemp3$datset), FUN="length")
	colnames(gsHHave) <- c("hour","doy", "year", "dataset","gc.mmol.s")
	gsHHave$gc.sd <- gsHHsd$x
	gsHHave$gc.n <- gsHHn$x
	gsHHave$gc.se <- gsHHave$gc.sd/sqrt(gsHHave$gc.n)
#label the site
		gsDave$site <- ifelse(gsDave$dataset==1|gsDave$dataset==2,"ld","hd")
		gsHHave$site <- ifelse(gsHHave$dataset==1|gsHHave$dataset==2,"ld","hd")
	
#################################################################
####make a panel of met and T and gc calc                 #######
#################################################################