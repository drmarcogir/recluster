biodecrypt<-function(mat,id,alpha=NULL,ratio=2.5,buffer=90,fraction=0.95, partCount = 10, clipToCoast="terrestrial", checkdist=T, proj = "+proj=longlat +datum=WGS84", minimum=7, map=NULL,xlim=NULL,ylim=NULL,main=NULL){
	res<-NULL
	res$type<-"sep"
	borders<-NULL
	taxa<-max(id)
	colnames(mat)<-c("Long","Lat")
	distances<-matrix(0,nrow(mat), taxa)
	distances2<-matrix(0,nrow(mat), taxa)
	if(is.null(alpha)){
		alpha=rep(8,taxa)
	}
	if(is.null(xlim)){
		xlim<-c(min(mat[,1]),max(mat[,1]))
	}
	if(is.null(ylim)){
		ylim<-c(min(mat[,2]),max(mat[,2]))
	}
	#plot(cbind(xlim,ylim),type="n",main=main)
	#if(!is.null(map)){
	#	plot(map,add=T)
	#}
	vectab<-matrix(0,nrow(mat),taxa+1)
	#points(mat,col="grey",cex=0.2)
	#points(mat,col=id,cex=0.25)
	hulls<-list()
	areas<-NULL
	oldw <- getOption("warn")
	options(warn = -1)
	for (spec in 1:taxa){
		#spec<-1
		taxsp<-which(id==spec)
		hulla<-mat[taxsp,]
		hullas<-hulla[!duplicated(hulla), ]
		if(nrow(hullas)>=minimum){
			hull<-rangeBuilder::getDynamicAlphaHull(hullas[,c(1,2)],fraction=fraction, partCount = partCount, buff = 0, clipToCoast=clipToCoast, proj=proj, initialAlpha=alpha[spec])[[1]]
	  	}
		if(nrow(hullas)<minimum){
			coordinates(hullas) <- ~Long+Lat
			hull <- rgeos::gConvexHull(hullas)
			proj4string(hull) <- proj 
			data(gshhs, envir = environment())
			if (clipToCoast != "no") {
				data(gshhs, envir = environment())
				gshhs <- sp::spTransform(gshhs, CRS(proj4string(hull)))
				if (clipToCoast == "terrestrial") {
					hull <- rgeos::gIntersection(hull, gshhs)
				}
			  	else {
			    	hull <- rgeos::gDifference(hull, gshhs)
				}
			}
		}
		hulls[spec]<-hull 
		areas[spec]<-raster::area(hulls[[spec]])/1000000
		#plot(hull,border=spec,add=T)
		vectab[prevR::point.in.SpatialPolygons(mat[,1], mat[,2],hull),spec]<-1	
		fuo<-which(id==spec & vectab[,spec]==0)
		fuori<-mat[fuo,]
		distneed<-which(vectab[,spec]==0 & id==0)
		if(length(distneed>0)){
			needdist<-mat[which(vectab[,spec]==0 & id==0),] 		  
			disthull<-geosphere::dist2Line(needdist,hull)[,1]/1000
		}
		if(length(fuo)>1 & length(which(vectab[,spec]==0 & id==0))==1){
			distpoints<-(geosphere::distm(rbind(fuori, needdist), fun=distGeo)/1000)
			distpointsneed<-distpoints[(length(fuo)+1):nrow(distpoints),(1:length(fuo))]
			distot<-c(disthull, distpointsneed)
			distances[which(vectab[,spec]==0 & id==0),spec]<-min(distot)
		}
		if(length(fuo)>1 & length(which(vectab[,spec]==0 & id==0))>1){
			distpoints<-(geosphere::distm(rbind(fuori, needdist), fun=distGeo)/1000)
			distpointsneed<-distpoints[(length(fuo)+1):nrow(distpoints),(1:length(fuo))]
			distot<-cbind(disthull, distpointsneed)
			distmin<-apply(distot, 1, FUN=min)
			distances[which(vectab[,spec]==0 & id==0),spec]<-distmin
		}
		if(length(fuo)==1 & length(which(vectab[,spec]==0 & id==0))>1 ){
			distpoints<-(geosphere::distm(rbind(fuori, needdist), fun=distGeo)/1000)
			distpointsneed<-distpoints[2:nrow(distpoints),1]
			distot<-cbind(disthull, distpointsneed)
			distmin<-apply(distot, 1, FUN=min)
			distances[which(vectab[,spec]==0 & id==0),spec]<-distmin	
		}
		if(length(fuo)==1 & length(which(vectab[,spec]==0 & id==0))==1 ){
			distpoints<-(geosphere::distm(rbind(fuori, needdist), fun=distGeo)/1000)
			distpointsneed<-distpoints[2:nrow(distpoints),1]
			distot<-c(disthull, distpointsneed)			
			distances[which(vectab[,spec]==0 & id==0),spec]<-min(distot)	
		}
		if(length(fuo)==0){
			distances[which(vectab[,spec]==0 & id==0),spec]<-disthull
		}	 
	}	
	vectab[,ncol(vectab)]<-rowSums(vectab[,1:taxa])
	id2<-id
	uncertain1<-which(vectab[,ncol(vectab)]>1 & id==0)
	uncertain2<-which(vectab[,ncol(vectab)]==0 & id==0)
	inside<-which(vectab[,ncol(vectab)]==1 & id==0)
	if (length(uncertain2)>1){
		distancesunc<-distances[uncertain2,]
		order<-matrix(NA,length(uncertain2),taxa)
		for (unc2 in 1:length(uncertain2)){
			wh<-uncertain2[unc2]
			order[unc2,1:taxa]<-c(1:taxa)[order(distancesunc[unc2,1:taxa])]
			}
		attribution<-order[,1]	
		for (k in 1:length(uncertain2)){
			dist<-distancesunc[k,]
			ordereddist<-dist[order(dist)]
			if(ordereddist[2]>buffer & (ordereddist[2]/ordereddist[1])>ratio){
				id2[uncertain2[k]]<-attribution[k]
			}
		}
	}
	if (length(uncertain2)==1){
		distancesunc<-distances[uncertain2,]
		order<-matrix(NA,1,taxa)
		order[1,1:taxa]<-c(1:taxa)[order(distancesunc[1:taxa])]
		attribution<-order[,1]
		ordereddist<-distancesunc[order(distancesunc)]
		if(ordereddist[2]>buffer & (ordereddist[2]/ordereddist[1])>ratio){
				id2[uncertain2]<-attribution

		}
	
	}
	if (length(inside)>1){
		distancesunc<-distances[inside,]
		for (k in 1: length(inside)){
			#k<-50
			attr<-which(vectab[inside[k],1:taxa]==1)
			diste<-distancesunc[k,]
			diste<-diste[-attr]
			if(min(diste)>buffer){
				id2[inside[k]]<-attr
			}
		}
	}	
	if (length(inside)==1){
		distancesunc<-distances[inside,]
		attr<-which(vectab[inside,1:taxa]==1)
		diste<-distancesunc[-attr]
		if(min(diste)>buffer){
			id2[inside]<-attr	
		}	
	}
	if(checkdist){
	  check<-which(id2>0 & id==0)
	  if(length(check>0)){
	    for(ch in 1:length(check)){
	 	attrp<-id2[check[ch]]
	      dist1<-geosphere::distGeo(mat[check[ch],], mat[which(id>0),])
	      minimum<-aggregate(dist1~id[which(id>0)],FUN="min")
	      mini<-which(minimum[,2]==min(minimum[,2]))
	      if(attrp!=mini){
	        id2[check[ch]]<-0
	      }
	    }
	  }
	}
	intersect<-matrix(NA,taxa,taxa)
	sympatry<-intersect
	for(k in 1:(taxa-1)){
		for(c in 2:taxa){
			inter<-raster::intersect(hulls[[k]],hulls[[c]])
			if(!is.null(inter)){
				intersect[k,c]<-(raster::area(inter)/1000000)
				sympatry[k,c]<-(raster::area(inter)/1000000)/(areas[c]+areas[k]-area(inter)/1000000)
				intersect[c,k]<-intersect[k,c]
				sympatry[c,k]<-sympatry[k,c]
			}
			if(is.null(inter)){
				intersect[k,c]<-0
				sympatry[k,c]<-0
				intersect[c,k]<-intersect[k,c]
				sympatry[c,k]<-sympatry[k,c]
			}		
		}
	}	
	options(warn = oldw)
	res$areas<-areas
	res$intersections<-intersect
	res$sympatry<-sympatry
	res$NUR<-(length(which(id2==0))/length(which(id==0)))*100
	res$table<-cbind(mat,id2,id)
	return(res)
	points(mat,col=id2,cex=0.5)
}
