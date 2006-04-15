######################################################################
#
# dataprep.R
#
# copyright (c) 2004, Carter T. Butts <buttsc@uci.edu>
# Last Modified 8/17/05
# Licensed under the GNU General Public License version 2 (June, 1991)
#
# Part of the R/sna package
#
# This file contains various routines for preparing/preprocessing data
# for use with the sna package.
#
# Contents:
#
#   addisolates (defunct)
#   add.isolates
#   as.sociomatrix.sna
#   diag.remove
#   event2dichot
#   gvectorize
#   interval.graph
#   lower.tri.remove
#   make.stochastic
#   nties
#   sr2css
#   stackcount
#   symmetrize
#   upper.tri.remove
#
######################################################################


#addisolates (Defunct, as of 1.0)
addisolates<-function(dat,n){
  .Defunct("add.isolates","sna")
}


#add.isolates - Add isolates to one or more graphs
add.isolates<-function(dat,n){
   #Pre-process the raw input
   dat<-as.sociomatrix.sna(dat)
   if(is.list(dat))
     return(lapply(dat,add.isolates,n=n))
   #End pre-processing
   if(length(dim(dat))>2){
      d<-array(dim=c(dim(dat)[1],dim(dat)[2]+n,dim(dat)[3]+n))
      d[,,]<-0
      for(i in 1:dim(dat)[1])
         d[i,1:dim(dat)[2],1:dim(dat)[2]]<-dat[i,,]
   }
   else{
      d<-matrix(nrow=dim(dat)[1]+n,ncol=dim(dat)[2]+n)
      d[,]<-0
      d[1:dim(dat)[2],1:dim(dat)[2]]<-dat
   }   
   d
}


#Force the input into sociomatrix form.  This function includes an sna
#wrapper to the network function as.sociomatrix, for global happiness.
as.sociomatrix.sna<-function(x, attrname=NULL, simplify=TRUE){
  #Check for the network library
  if("network"%in%(.packages()))
    return(as.sociomatrix(x, attrname=NULL, simplify=TRUE))
  #Otherwise, proceed apace
  if((class(x)=="network")||(is.list(x)&&any(sapply(x,class)=="network"))){
    require("network")  #Must have network library to process network objects
    return(as.sociomatrix(x, attrname=NULL, simplify=TRUE))
  }
  #Coerce to adjacency matrix form -- by now, no network class involved
  if(is.matrix(x)||is.array(x)){ #If an array/matrix, use as-is
    g<-x
  }else if(is.list(x)){  #If a list, recurse on list elements
    g<-lapply(x,as.sociomatrix.sna,attrname=attrname,simplify=simplify)
#    g<-x
  }else{
    stop("as.sociomatrix.sna input must be an adjacency matrix/array, network, or list.")
  }
  #Convert into the appropriate return format
  if(is.list(g)){   #Collapse if needed
    if(length(g)==1){
      g<-g[[1]]
      if((!simplify)&&(length(dim(g))==3)){  #Coerce to a list of matrices?
        out<-list()
        for(i in 1:dim(g)[1])
          out[[i]]<-g[i,,]
      }else{
        out<-g
      }
    }else{
      #Coerce to array form?
      if(simplify){
        dims<-sapply(g,dim)
        if(is.list(dims)){      #Dims must not be of equal length
          mats<-sapply(dims,length)
          mats[mats==1]<-0
          mats[mats==2]<-1
          mats[mats==3]<-sapply(dims[mats==3],"[[",1)
          mats<-cumsum(mats)
          dims<-sapply(dims,"[",2)
        }else{                  #Dims are of equal length
          if(NROW(dims)==3)      #Determine number of matrices per entry
            mats<-cumsum(dims[1,])
          else
            mats<-1:NCOL(dims)
          dims<-dims[2,]         #Get ncols
        }
        if((!any(is.null(dims)))&&(length(unique(dims))==1)&&(all(mats>0))){
          out<-array(dim=c(mats[length(mats)],dims[1],dims[1]))
          for(i in 1:length(mats))
            out[(c(0,mats)[i]+1):(mats[i]),,]<-g[[i]]
        }else
          out<-g
      }else
        out<-g
    }
  }else{
    if((!simplify)&&(length(dim(g))==3)){  #Coerce to a list of matrices?
      out<-list()
      for(i in 1:dim(g)[1])
        out[[i]]<-g[i,,]
    }else
      out<-g
  }
  #Return the result
  out
}



#diag.remove - NA the diagonals of adjacency matrices in a graph stack
diag.remove<-function(dat,remove.val=NA){
   #Pre-process the raw input
   dat<-as.sociomatrix.sna(dat)
   if(is.list(dat))
     return(lapply(dat,diag.remove,remove.val=remove.val))
   #End pre-processing
   if(length(dim(dat))>2){
      d<-dat
      for(i in 1:dim(dat)[1])
         diag(d[i,,])<-remove.val
   }
   else{
      d<-dat
      diag(d)<-remove.val
   }   
   d
}


#event2dichot - Convert an observed event matrix to a dichotomous matrix.  
#Methods are quantile, mean, rquantile, rmean, cquantile, cmean, absolute, rank,
#rrank, and crank.  Thresh specifies the cutoff, in terms of whatever method is 
#used (if applicable).
event2dichot<-function(m,method="quantile",thresh=0.5,leq=FALSE){
   #Pre-process the raw input
   m<-as.sociomatrix.sna(m)
   if(is.list(m))
     return(lapply(m,event2dichot,method=method,thresh=thresh,leq=leq))
   #End pre-processing
   if(method=="quantile"){
      q<-quantile(m,thresh,na.rm=TRUE, names=FALSE)
      out<-as.numeric(m>q)
   } else if(method=="rquantile"){
      q<-quantile(m[1,],thresh,na.rm=TRUE, names=FALSE)
      out<-as.numeric(m[1,]>q)
      for(i in 2:dim(m)[1]){      
         q<-quantile(m[i,],thresh,na.rm=TRUE, names=FALSE)
         out<-rbind(out,as.numeric(m[i,]>q))
      }
   } else if(method=="cquantile"){
      q<-quantile(m[,1],thresh,na.rm=TRUE, names=FALSE)
      out<-as.numeric(m[,1]>q)
      for(i in 2:dim(m)[2]){      
         q<-quantile(m[,i],thresh,na.rm=TRUE, names=FALSE)
         out<-cbind(out,as.numeric(m[,i]>q))
      }
   } else if(method=="mean"){
      q<-mean(m)
      out<-as.numeric(m>q)
   } else if(method=="rmean"){
      q<-mean(m[1,])
      out<-as.numeric(m[1,]>q)
      for(i in 2:dim(m)[1]){      
         q<-mean(m[i,])
         out<-rbind(out,as.numeric(m[i,]>q))
      }
   } else if(method=="cmean"){
      q<-mean(m[,1])
      out<-as.numeric(m[,1]>q)
      for(i in 2:dim(m)[2]){      
         q<-mean(m[,i])
         out<-rbind(out,as.numeric(m[,i]>q))
      }
   } else if(method=="absolute"){
      out<-as.numeric(m>thresh)
   } else if(method=="rank"){
      o<-order(m)
      out<-as.numeric((max(o)-o+1)<thresh)
   } else if(method=="rrank"){
      o<-order(m[1,])
      out<-as.numeric((max(o)-o+1)<thresh)
      for(i in 2:dim(m)[1]){      
         o<-order(m[i,])
         out<-rbind(out,as.numeric((max(o)-o+1)<thresh))
      }
   } else if(method=="crank"){
      o<-order(m[,1])
      out<-as.numeric((max(o)-o+1)<thresh)
      for(i in 2:dim(m)[2]){      
         o<-order(m[,i])
         out<-cbind(out,as.numeric((max(o)-o+1)<thresh))
      }
   }
   if(leq==TRUE)
      out<-1-out
   if(is.null(dim(out))!=is.null(dim(m)))
      out<-array(out,dim=dim(m))
   else
      if(dim(out)!=dim(m))
         out<-array(out,dim=dim(m))
   out
}


#gvectorize - Vectorization of adjacency matrices
gvectorize<-function(mats,mode="digraph",diag=FALSE,censor.as.na=TRUE){
   #Pre-process the raw input
   mats<-as.sociomatrix.sna(mats)
   if(is.list(mats))
     return(lapply(mats,gvectorize,mode=mode,diag=diag, censor.as.na=censor.as.na))
   #End pre-processing
   #Build the input data structures
   if(length(dim(mats))>2){
      m<-dim(mats)[1]
      n<-dim(mats)[2]
      n<-dim(mats)[3]
      d<-mats
   }else{
      m<-1
      n<-dim(mats)[1]
      o<-dim(mats)[2]
      d<-array(dim=c(1,n,o))
      d[1,,]<-mats
   }
   #If using NA censoring, turn unused parts of the matrices to NAs and vectorize
   if(censor.as.na){
      if(mode=="graph")
         d<-upper.tri.remove(d)
      if(!diag)
         d<-diag.remove(d)
      out<-apply(d,1,as.vector)
   }else{   #Otherwise, vectorize only the useful parts
      mask<-apply(d,1,lower.tri,diag=diag)
      out<-apply(d,1,as.vector)
      if(m==1)
         out<-out[mask]
      else
         out<-matrix(out[mask],ncol=m)      
   }
   out
}


#interval.graph - Construct one or more interval graphs (and exchangeability 
#vectors) from a set of spells
interval.graph<-function(slist,type="simple",diag=FALSE){
   #Note that each slice of slist must have one spell per row, with col 1 containing the spell type,
   #col 2 containing the spell onset, and col 3 containing the spell termination.  If there are multiple
   #slices present, they must be indexed by the first dimension of the array.
   #First, the preliminaries
   o<-list()
   m<-stackcount(slist)          #Get the number of stacks
   if(m==1){
      d<-array(dim=c(m,dim(slist)[1],dim(slist)[2]))
      d[1,,]<-slist
   }else
      d<-slist
   ns<-dim(d)[2]                     #Get the number of spells
   o$exchange.list<-d[,,1]   #Exchange list is just the vector of spell types
   #Now, for the graph itself...
   o$graph<-array(dim=c(m,ns,ns))
   for(i in 1:ns)
      for(j in 1:ns)
         o$graph[,i,j]<-switch(type,
            simple=as.numeric((d[,i,2]<=d[,j,3])&(d[,i,3]>=d[,j,2])),  #"Start before the end, end after the beginning"
            overlap=pmax(pmin(d[,i,3],d[,j,3])-pmax(d[,i,2],d[,j,2]),0),
            fracxy=pmax(pmin(d[,i,3],d[,j,3])-pmax(d[,i,2],d[,j,2]),0)/(d[,i,3]-d[,i,2]),
            fracyx=pmax(pmin(d[,i,3],d[,j,3])-pmax(d[,i,2],d[,j,2]),0)/(d[,j,3]-d[,j,2]),
            jntfrac=2*pmax(pmin(d[,i,3],d[,j,3])-pmax(d[,i,2],d[,j,2]),0)/(d[,i,3]-d[,i,2]+d[,j,3]-d[,j,2])
         )
   #Patch up those loose ends.
   if(m==1)
      o$graph<-o$graph[1,,]
   if(!diag)
      o$graph<-diag.remove(o$graph,remove.val=0)
   #Return the data structure
   o
}


#lower.tri.remove - NA the lower triangles of adjacency matrices in a graph 
#stack
lower.tri.remove<-function(dat,remove.val=NA){
   #Pre-process the raw input
   dat<-as.sociomatrix.sna(dat)
   if(is.list(dat))
     return(lapply(dat,lower.tri.remove,val=remove.val))
   #End pre-processing
   if(length(dim(dat))>2){
      d<-dat
      for(i in 1:dim(dat)[1]){
         temp<-d[i,,]
         temp[lower.tri(temp,diag=FALSE)]<-remove.val
         d[i,,]<-temp
      }
   }
   else{
      d<-dat
      d[lower.tri(d,diag=FALSE)]<-remove.val
   }   
   d
}


#make.stochastic - Make a graph stack row, column, or row-column stochastic
make.stochastic<-function(dat,mode="rowcol",tol=0.005,maxiter=prod(dim(dat))*100,anneal.decay=0.01,errpow=1){
   #Pre-process the raw input
   dat<-as.sociomatrix.sna(dat)
   if(is.list(dat))
     return(lapply(dat,make.stochastic,mode=mode,tol=tol,maxiter=maxiter, anneal.decay=anneal.decay,errpow=errpow))
   #End pre-processing
   #Organize the data
   m<-stackcount(dat)
   if(m==1){
      n<-dim(dat)[1]
      o<-dim(dat)[2]
      d<-array(dim=c(m,n,o))
      d[1,,]<-dat
   }else{
      n<-dim(dat)[2]
      o<-dim(dat)[3]
      d<-dat
   }
   #Stochasticize
   if(mode=="row"){
      for(i in 1:m)
         d[i,,]<-d[i,,]/t(sapply(apply(d[i,,],1,sum),rep,o))
   }else if(mode=="col"){
      for(i in 1:m)
         d[i,,]<-d[i,,]/sapply(apply(d[i,,],2,sum),rep,n)
   }else if(mode=="rowcol"){
      for(i in 1:m){
         f<-d[i,,]/t(sapply(apply(d[i,,],1,sum),rep,o))   #Seed with the row-stochastic form
         f<-f/sapply(apply(f,2,sum),rep,n)   #Col-stochasticize for good measure (sometimes this works)
         edgelist<-cbind(rep(1:n,o),rep(1:o,rep(n,o)))
         edgelist<-edgelist[d[i,,][edgelist]>0,]   #Skip edges which are forced to be zero-valued
         err<-sum(abs(apply(f,2,sum)-rep(1,o))^errpow,abs(apply(f,1,sum)-rep(1,n))^errpow)
         iter<-0
         while((err>(n+o)*tol)&(iter<maxiter)){  #Right now, use an annealer to find an approximate solution
            edge<-sample(1:dim(edgelist)[1],1)
            x<-edgelist[edge,1]
            y<-edgelist[edge,2]
            draw<-max(0,min(rnorm(1,f[x,y],d[i,x,y]/10),d[i,x,y]))
            nerr<-err-abs(sum(f[x,])-1)^errpow-abs(sum(f[,y])-1)^errpow+abs(sum(f[x,][-y])+draw-1)^errpow+abs(sum(f[,y][-x])+draw-1)^errpow
            if((nerr<err)|(runif(1,0,1)<exp(-anneal.decay*iter))){
               f[x,y]<-draw
               err<-nerr
            }
            iter<-iter+1
         }
         d[i,,]<-f
         if(err>(n+o)*tol)
            warning(paste("Annealer unable to reduce total error below apx",round(err,digits=7),"in matrix",i,". Hope that's OK....\n"))
      }
   }else if(mode=="total"){
         for(i in 1:m)
            d[i,,]<-d[i,,]/sum(d[i,,])
   }
   #Patch NaN values
   d[is.nan(d)]<-0
   #Return the output
   if(m==1)
      d[1,,]
   else
      d
}


#nties - Find the number of ties in a given graph or stack
nties<- function(dat,mode="digraph",diag=FALSE){
   #Pre-process the raw input
   dat<-as.sociomatrix.sna(dat)
   if(is.list(dat))
     return(lapply(dat,nties,mode=mode,diag=diag))
   #End pre-processing
   #Did someone send us a stack?
   if(length(dim(dat))>2)
      shiftit<-1
   else
      shiftit<-0
   #Get size params
   n<-dim(dat)[1+shiftit]
   m<-dim(dat)[2+shiftit]
   #Sanity check for hypergraphs
   if(mode=="hgraph")
      diag<-TRUE
   #Get the initial count
   count<-switch(mode,
      digraph = n*n,
      graph = (n*n-n)/2+n,
      hgraph = n*m
   )
   #Modify for diag, if needed
   if(!diag)
      count<-count-n
   #Return the needed info
   if(shiftit)
      rep(count,dim(dat)[1])
   else
      count                
}


#sr2css - Convert a row-wise self-report matrix to a CSS matrix with missing 
#observations.
sr2css<-function(net){
   #Pre-process the raw input
   dat<-as.sociomatrix.sna(net)
   if(is.list(net))
     return(lapply(net))
   #End pre-processing
   n<-dim(net)[1]
   css<-array(dim=c(n,n,n))
   for(i in 1:n){
      css[i,,]<-NA
      css[i,i,]<-net[i,]
   }
   css
}


#stackcount -How many matrices in a given stack?
stackcount<-function(d){
   #Pre-process the raw input
   d<-as.sociomatrix.sna(d)
   if(is.list(d))
     return(sum(sapply(d,stackcount)))
   #End pre-processing
   if(length(dim(d))>2)
      dim(d)[1]
   else
      1
}


#symmetrize - Convert a graph or graph stack to a symmetric form.  Current rules
#for symmetrizing include "upper" and "lower" diagonals, "weak" connectedness 
#rule, and a "strong" connectedness rule.
symmetrize<-function(mats,rule="weak"){
   #Pre-process the raw input
   mats<-as.sociomatrix.sna(mats)
   if(is.list(mats))
     return(lapply(mats,symmetrize,rule=rule))
   #End pre-processing
   #Build the input data structures
   if(length(dim(mats))>2){
      m<-dim(mats)[1]
      n<-dim(mats)[2]
      o<-dim(mats)[3]
      d<-mats
   }else{
      m<-1
      n<-dim(mats)[1]
      o<-dim(mats)[2]
      d<-array(dim=c(1,n,o))
      d[1,,]<-mats
   }
   #Apply the symmetry rule
   for(i in 1:m){
      if(rule=="upper"){
         temp<-d[i,,]
         for(j in 1:n)
            temp[j:n,j]<-temp[j,j:n]
         d[i,,]<-temp
      }else if(rule=="lower"){
         temp<-d[i,,]
         for(j in 1:n)
            temp[j,j:n]<-temp[j:n,j]
         d[i,,]<-temp
      }else if(rule=="weak"){
         d[i,,]<-matrix(as.numeric(d[i,,]|t(d[i,,])),nrow=n,ncol=o)
      }else if(rule=="strong"){
         d[i,,]<-matrix(as.numeric(d[i,,]&t(d[i,,])),nrow=n,ncol=o)
      }
   }
   #Return the symmetrized matrix
   if(m==1)
      out<-d[1,,]
   else
      out<-d
   out
}


#upper.tri.remove - NA the upper triangles of adjacency matrices in a graph 
#stack
upper.tri.remove<-function(dat,remove.val=NA){
   #Pre-process the raw input
   dat<-as.sociomatrix.sna(dat)
   if(is.list(dat))
     return(lapply(dat,upper.tri.remove,remove.val=remove.val))
   #End pre-processing
   if(length(dim(dat))>2){
      d<-dat
      for(i in 1:dim(dat)[1]){
         temp<-d[i,,]
         temp[upper.tri(temp,diag=FALSE)]<-remove.val
         d[i,,]<-temp
      }
   }
   else{
      d<-dat
      d[upper.tri(d,diag=FALSE)]<-remove.val
   }   
   d
}

