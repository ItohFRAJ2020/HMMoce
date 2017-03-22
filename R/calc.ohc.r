#' Calculate Ocean Heat Content (OHC) probability surface
#' 
#' Compare tag data to OHC grid and calculate likelihoods
#' 
#' @param pdt is variable containing tag-collected PDT data
#' @param ptt is unique tag identifier
#' @param isotherm default '' in which isotherm is calculated on the fly based 
#'   on daily tag data. Otherwise, numeric isotherm constraint can be specified 
#'   (e.g. 20 deg C).
#' @param ohc.dir local directory where \code{get.env} downloads are stored.
#' @param dateVec is vector of dates from tag to pop-up in 1 day increments.
#' @param bathy is logical indicating whether or not a bathymetric mask should
#'   be applied
#' @param use.se is logical indicating whether or not to use SE when using regression to predict temperature at specific depth levels.
#'   
#' @return likelihood is raster brick of likelihood surfaces representing 
#'   estimated position based on tag-based OHC compared to calculated OHC using 
#'   HYCOM
#'   
#' @export
#' @seealso \code{\link{calc.woa}}
#' @examples
#' \dontrun{
#' # depth-temp profile data
#' pdt <- read.wc(ptt, wd = myDir, type = 'pdt', tag=tag, pop=pop); 
#' pdt.udates <- pdt$udates; pdt <- pdt$data
#' # GENERATE DAILY OCEAN HEAT CONTENT (OHC) LIKELIHOODS
#' L.ohc <- calc.ohc(pdt, ptt, ohc.dir = hycom.dir, dateVec = dateVec,
#'                   isotherm = '')
#' }

calc.ohc <- function(pdt, ptt, isotherm = '', ohc.dir, dateVec, bathy = TRUE, use.se = TRUE){

  options(warn=1)
  
  t0 <- Sys.time()
  print(paste('Starting OHC likelihood calculation...'))
  
  # constants for OHC calc
  cp <- 3.993 # kJ/kg*C <- heat capacity of seawater
  rho <- 1025 # kg/m3 <- assumed density of seawater
  
  # calculate midpoint of tag-based min/max temps
  pdt$MidTemp <- (pdt$MaxTemp + pdt$MinTemp) / 2
  
  # get unique time points
  udates <- unique(pdt$Date)
  T <- length(udates)
  
  if(isotherm != '') iso.def <- TRUE else iso.def <- FALSE
  
  print(paste('Starting iterations through deployment period ', '...'))
  
  for(i in 1:T){
    time <- udates[i]
    pdt.i <- pdt[which(pdt$Date == time),]
    #print(paste(time))
    
    # open day's hycom data
    nc <- RNetCDF::open.nc(paste(ohc.dir, ptt,'_', as.Date(time), '.nc', sep=''))
    dat <- RNetCDF::var.get.nc(nc, 'water_temp') * RNetCDF::att.get.nc(nc, 'water_temp', attribute='scale_factor') + 
      RNetCDF::att.get.nc(nc, variable='water_temp', attribute='add_offset')
    
    if(i == 1){
      depth <- RNetCDF::var.get.nc(nc, 'depth')
      lon <- RNetCDF::var.get.nc(nc, 'lon')
      lat <- RNetCDF::var.get.nc(nc, 'lat')
    }
    
    #extracts depth from tag data for day i
    y <- pdt.i$Depth[!is.na(pdt.i$Depth)] 
    y[y<0] <- 0
    
    #extract temperature from tag data for day i
    x <- pdt.i$MidTemp[!is.na(pdt.i$Depth)]  
    
    # use the which.min
    depIdx = unique(apply(as.data.frame(pdt.i$Depth), 1, FUN=function(x) which.min((x - depth) ^ 2)))
    hycomDep <- depth[depIdx]
    
    if(bathy){
      mask <- dat[,,max(depIdx)]
      mask[is.na(mask)] <- NA
      mask[!is.na(mask)] <- 1
      for(bb in 1:length(depth)){
        dat[,,bb] <- dat[,,bb] * mask
      }
    }
    
    # make predictions based on the regression model earlier for the temperature at standard WOA depth levels for low and high temperature at that depth
    suppressWarnings(
    fit.low <- locfit::locfit(pdt.i$MinTemp ~ pdt.i$Depth, maxk=500)
    )
    suppressWarnings(
    fit.high <- locfit::locfit(pdt.i$MaxTemp ~ pdt.i$Depth, maxk=500)
    )
    n = length(hycomDep)
      
    #suppressWarnings(
    pred.low = stats::predict(fit.low, newdata = hycomDep, se = T, get.data = T)
    #suppressWarnings(
    pred.high = stats::predict(fit.high, newdata = hycomDep, se = T, get.data = T)
    
    if (use.se){
      # data frame for next step
      df = data.frame(low = pred.low$fit - pred.low$se.fit * sqrt(n),
                      high = pred.high$fit + pred.high$se.fit * sqrt(n),
                      depth = hycomDep)
    } else{
      # data frame for next step
      df = data.frame(low = pred.low$fit,# - pred.low$se.fit * sqrt(n),
                      high = pred.high$fit,# + pred.high$se.fit * sqrt(n),
                      depth = hycomDep)
    }

    # isotherm is minimum temperature recorded for that time point
    if(iso.def == FALSE) isotherm <- min(df$low, na.rm = T)
    
    # perform tag data integration at limits of model fits
    minT.ohc <- cp * rho * sum(df$low - isotherm, na.rm = T) / 10000
    maxT.ohc <- cp * rho * sum(df$high - isotherm, na.rm = T) / 10000
    
    # Perform hycom integration
    dat[dat < isotherm] <- NA
    dat <- dat - isotherm
    ohc <- cp * rho * apply(dat[,,depIdx], 1:2, sum, na.rm = T) / 10000 
    ohc[ohc == 0] <- NA
    
    # calc sd of OHC
    # focal calc on mean temp and write to sd var
    r = raster::flip(raster::raster(t(ohc)), 2)
    sdx = raster::focal(r, w = matrix(1, nrow = 9, ncol = 9),
                        fun = function(x) stats::sd(x, na.rm = T))
    sdx = t(raster::as.matrix(raster::flip(sdx, 2)))

    # compare hycom to that day's tag-based ohc
    #lik.ohc <- likint3(ohc, sdx, minT.ohc, maxT.ohc)
    #lik.ohc <- lik.ohc / max(lik.ohc, na.rm = T)
    
    lik.try <- try(likint3(ohc, sdx, minT.ohc, maxT.ohc), TRUE)
    
    if(class(lik.try) == 'try-error' & use.se == FALSE){
      
      # try ohc again with use.se = T
      df = data.frame(low = pred.low$fit - pred.low$se.fit * sqrt(n),
                      high = pred.high$fit + pred.high$se.fit * sqrt(n),
                      depth = hycomDep)
      
      minT.ohc <- cp * rho * sum(df$low - isotherm, na.rm = T) / 10000
      maxT.ohc <- cp * rho * sum(df$high - isotherm, na.rm = T) / 10000
      
      lik.try <- try(likint3(ohc, sdx, minT.ohc, maxT.ohc), TRUE)
      
      if (class(lik.try) == 'try-error'){
        lik.try <- ohc * 0
        warning(paste('Warning: likint3 failed after trying with and without SE prediction of depth-temp profiles. This is most likely a divergent integral for ', time, '...', sep=''))
      }
      
    } else if (class(lik.try) == 'try-error' & use.se == TRUE){
      lik.try <- ohc * 0
      warning(paste('Warning: likint3 failed after trying with and without SE prediction of depth-temp profiles. This is most likely a divergent integral for ', time, '...', sep=''))
    }
    
    lik.ohc <- lik.try / max(lik.try, na.rm = T)
    
    if(i == 1){
      # result will be array of likelihood surfaces
      L.ohc <- array(0, dim = c(dim(lik.ohc), length(dateVec)))
    }
    
    idx <- which(dateVec == as.Date(time))
    L.ohc[,,idx] = lik.ohc

  }

  print(paste('Making final likelihood raster...'))
  
  crs <- "+proj=longlat +datum=WGS84 +ellps=WGS84"
  list.ohc <- list(x = lon-360, y = lat, z = L.ohc)
  ex <- raster::extent(list.ohc)
  L.ohc <- raster::brick(list.ohc$z, xmn=ex[1], xmx=ex[2], ymn=ex[3], ymx=ex[4], transpose=T, crs)
  L.ohc <- raster::flip(L.ohc, direction = 'y')

  L.ohc[L.ohc < 0] <- 0
  
  t1 <- Sys.time()
  print(paste('OHC calculations took ', round(as.numeric(difftime(t1, t0, units='mins')), 2), 'minutes...'))
  
  # return ohc likelihood surfaces
  return(L.ohc)
  
}

