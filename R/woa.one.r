#' World Ocean Atlas 2013 Temperature Data
#'
#' A dataset containing the objectively analyzed (1 degree grid) climatological in situ temperature. These are monthly composits at standard depth levels for the World Ocean. For more information see https://www.nodc.noaa.gov/OC5/woa13/
#'
#' @docType data
#'
#' @usage data(woa.one)
#'
#' @format A list of 4 objects:
#' \describe{
#'   \item{watertemp}{an array of climatological average of sea water temperature in degrees C. Dimensions are longitude, latitude, standard depth level, month of year.}
#'   \item{lon}{a vector of longitude values corresponding to dimension 1 of watertemp}
#'   \item{lat}{a vector of latitude values corresponding to dimension 2 of watertemp}
#'   \item{depth}{a vector of standard water depth levels in meters}
#' }
#' @references Boyer, T.P., J. I. Antonov, O. K. Baranova, C. Coleman, H. E. Garcia, A. Grodsky, D. R. Johnson, R. A. Locarnini, A. V. Mishonov, T.D. O'Brien, C.R. Paver, J.R. Reagan, D. Seidov, I. V. Smolyar, and M. M. Zweng, 2013: World Ocean Database 2013, NOAA Atlas NESDIS 72, S. Levitus, Ed., A. Mishonov, Technical Ed.; Silver Spring, MD, 209 pp., http://doi.org/10.7289/V5NZ85MT
#' 
#' @source \url{https://www.nodc.noaa.gov/OC5/woa13/}
#' 
#' @examples 
#' \dontrun{
#' data(woa.one)
#' # need to load the 'fields' package
#' image.plot(woa.one$lon, woa.one$lat, woa.one$watertemp)
#' }

"woa.one"
#> [1] "woa.one"
