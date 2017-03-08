#' Calculate SST-based likelihood
#' 
#' \code{calc.sst} compares tag SST to remotely sensed SST and calculates
#' likelihoods
#' 
#' @param tag.sst variable containing tag-collected SST data
#' @param ptt is unique tag identifier
#' @param sst.dir local directory where remote sensing SST downloads are stored
#' @param dateVec is vector of dates from tag to pop-up in 1 day increments.
#' @param sens.err is numeric indicating the percent sensor error in the tag sst sensor. Default is 1.
#'
#' @return likelihood is raster brick of likelihood surfaces representing matches
#'   between tag-based sst and remotely sensed sst maps
#' 
#' @export
#' 
#' @seealso \code{\link{calc.ohc}}
#' 
#' @examples
#' \dontrun{
#' 
#' # sst data
#' tag.sst <- read.wc(ptt, wd = myDir, type = 'sst', tag=tag, pop=pop); 
#' sst.udates <- tag.sst$udates; tag.sst <- tag.sst$data
#' 
#' # IF YOU NEED TO DOWNLOAD SST DATA
#' sst.dir <- paste('my_sst_dir')
#' get.env(sst.udates, type = 'sst', spatLim = sp.lim, save.dir = sst.dir)
#' 
#' # GENERATE DAILY SST LIKELIHOODS
#' L.sst <- calc.sst(tag.sst, sst.dir = sst.dir, dateVec = dateVec)
#' 
#' }

calc.sst <- function(tag.sst, ptt, sst.dir, dateVec, sens.err = 1){
  
  start.t <- Sys.time()
  
  tag.sst$dts <- as.POSIXct(tag.sst$Date, format = findDateFormat(tag.sst$Date))
  by_dte <- dplyr::group_by(tag.sst, as.factor(tag.sst$dts))  # group by unique DAILY time points
  tag.sst <- data.frame(dplyr::summarise(by_dte, min(Temperature), max(Temperature)))
  colnames(tag.sst) <- list('date', 'minT', 'maxT')
  tag.sst$date <- as.Date(tag.sst$date)
  
  T <- length(tag.sst[,1])
  
  print(paste('Starting iterations through time ', '...'))
  
  for(i in 1:T){
    
    time <- tag.sst$date[i]
    sst.i <- c(tag.sst$minT[i] * (1 - sens.err / 100), tag.sst$maxT[i] * (1 + sens.err / 100)) # sensor error
    
    # open day's sst data
    nc <- RNetCDF::open.nc(paste(sst.dir, ptt, '_', as.Date(time), '.nc', sep='')) #add lat lon in filename '.nc', sep=''))
    
    if (i == 1){
      # get correct name in sst data
      ncnames = NULL
      nmax <- RNetCDF::file.inq.nc(nc)$nvars - 1
      for(ii in 0:nmax) ncnames[ii + 1] <- RNetCDF::var.inq.nc(nc, ii)$name
      nameidx <- grep('sst', ncnames) - 1
    }
    
    dat <- RNetCDF::var.get.nc(nc, nameidx) # for OI SST
    
    # calc sd of SST
    # focal calc on mean temp and write to sd var
    r = raster::flip(raster::raster(t(dat)), 2)
    sdx = raster::focal(r, w = matrix(1, nrow = 3, ncol = 3), fun = function(x) stats::sd(x, na.rm = T))
    sdx = t(raster::as.matrix(raster::flip(sdx, 2)))

    # compare sst to that day's tag-based ohc
    lik.sst <- likint3(dat, sdx, sst.i[1], sst.i[2])

    if(i == 1){
      lon <- RNetCDF::var.get.nc(nc, 'longitude')
      lat <- RNetCDF::var.get.nc(nc, 'latitude')
      # result will be array of likelihood surfaces
      L.sst <- array(0, dim = c(dim(lik.sst), length(dateVec)))
    }
    
    idx <- which(dateVec == as.Date(time))
    L.sst[,,idx] = lik.sst / max(lik.sst, na.rm=T)
    
  }
    
  print(paste('Making final likelihood raster...'))
  
  crs <- "+proj=longlat +datum=WGS84 +ellps=WGS84"
  list.sst <- list(x = lon, y = lat, z = L.sst)
  ex <- raster::extent(list.sst)
  L.sst <- raster::brick(list.sst$z, xmn=ex[1], xmx=ex[2], ymn=ex[3], ymx=ex[4], transpose=T, crs)
  L.sst <- raster::flip(L.sst, direction = 'y')
    
  L.sst[L.sst < 0] <- 0
  
  # return sst likelihood surfaces
  return(L.sst)
    
}
  