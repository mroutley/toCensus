#' Use census data to create Toronto agents
#'
#' Creates individual agents ("Torontonians") based on census data
#'
#' @return A dataframe containing all agents of voting age.
to_census <- function() {
  # 2010 Census data
  # census_file <- "http://www12.statcan.gc.ca/census-recensement/2011/dp-pd/prof/details/download-telecharger/comprehensive/comp_download.cfm?CTLG=98-316-XWE2011001&FMT=CSV401&Lang=E&Tab=1&Geo1=CSD&Code1=3520005&Geo2=CD&Code2=3520&Data=Count&SearchText=toronto&SearchType=Begins&SearchPR=01&B1=All&Custom=&TABID=1"
  # download.file(census_file, destfile = "data-raw/98-316-XWE2011001-401_CSV.zip")
  # unzip("data-raw/98-316-XWE2011001-401_CSV.zip", exdir="data-raw")
  census_df <- dplyr::tbl_df(read.csv(file="data-raw/98-316-XWE2011001-401.CSV", skip = 1))
  toronto_census <- dplyr::filter(census_df,CMACA_Name=="Toronto")
  toronto_census <- dplyr::select(toronto_census, Geo_Code, Characteristic, Total, Male, Female)
  characteristics_of_interest <- c("Median age of the population", "Average number of children at home per census family", "Total population by age groups","   0 to 4 years","   5 to 9 years","   10 to 14 years","      15 years","      16 years","      17 years","      18 years","      19 years","   20 to 24 years","   25 to 29 years","   30 to 34 years","   35 to 39 years","   40 to 44 years","   45 to 49 years","   50 to 54 years","   55 to 59 years","   60 to 64 years","   65 to 69 years","   70 to 74 years","   75 to 79 years","   80 to 84 years","   85 years and over")
  toronto_census <- dplyr::filter(toronto_census, Characteristic %in% characteristics_of_interest)
  toronto_census <- droplevels(toronto_census)
#   toronto_census$Geo_Code <- sprintf("%.2f", as.numeric(toronto_census$Geo_Code))
  toronto_census$Geo_Code <- as.character(toronto_census$Geo_Code)
  rm(toronto_census_file, census_df)
  pattern <-"^\\s+"
  levels(toronto_census$Characteristic) <- gsub(pattern, "", levels(toronto_census$Characteristic), perl = TRUE)
  levels(toronto_census$Characteristic)[23:25] <- c("children", "age", "population")

  #nhs_file <- "http://www12.statcan.gc.ca/nhs-enm/2011/dp-pd/prof/details/download-telecharger/comprehensive/comp-csv-tab-nhs-enm.cfm?Lang=E"
  # download.file(nhs_file, destfile = "data-raw/99-004-XWE2011001-401_CSV.zip")
  # unzip("data-raw/99-004-XWE2011001-401_CSV.zip", exdir="data-raw")
  on_nhs_df <- dplyr::tbl_df(read.csv(file="data-raw/99-004-XWE2011001-401-ONT.csv"))
  toronto_nhs <- dplyr::filter(on_nhs_df,CMA_CA_Name=="Toronto")
  toronto_nhs <- dplyr::select(toronto_nhs, Geo_Code, Characteristic, Total, Male, Female)
  characteristics_of_interest <- c("  Median family income ($)", "  Postsecondary certificate, diploma or degree", "Employment rate", "  Median income ($)")
  toronto_nhs <- dplyr::filter(toronto_nhs, Characteristic %in% characteristics_of_interest)
  toronto_nhs$Geo_Code <- as.character(toronto_nhs$Geo_Code)
  rm(on_nhs_df, nhs_file)
  toronto_census <- rbind(toronto_census, toronto_nhs)
  rm(toronto_nhs)
  toronto_census <- droplevels(toronto_census)
  levels(toronto_census$Characteristic)[26:29] <- c("family_income","income", "postsecondary", "employment")
  toronto_age <- dplyr::filter(toronto_census,Characteristic %in% (levels(toronto_census$Characteristic)[1:22]))
  toronto_age <- dplyr::select(toronto_age, Geo_Code, Characteristic, Male, Female)
  toronto_age <- reshape2::melt(toronto_age, id.vars = c("Characteristic", "Geo_Code"), value.name = "Population", variable.name = "Gender")
  names(toronto_age)[1] <- "Age"
  toronto_age <- droplevels(toronto_age)
  toronto_age <- dplyr::filter(toronto_age, Population != is.na(toronto_age$Population))
  age_gender_expanded <- data.frame(age=rep(toronto_age[,1], times=toronto_age[,4]), gender=rep(toronto_age[,3], times=toronto_age[,4]), Geo_Code=rep(toronto_age[,2], times=toronto_age[,4]))
  toronto_census <- dplyr::filter(toronto_census,!Characteristic %in% (levels(toronto_census$Characteristic)[1:22]))
  toronto_income <- dplyr::filter(toronto_census, Characteristic == "family_income")
  toronto_income <- dplyr::select(toronto_income, Geo_Code, Total)
  names(toronto_income)[2] <- "family_income"
  census <- droplevels(dplyr::filter(age_gender_expanded, age %in% levels(age_gender_expanded$age)[c(4:5,8:13,15:22)]))
  census <- dplyr::inner_join(census, toronto_income)
  census$income_range <- cut(census$family_income, breaks = c(seq(from = 0, to = 10, by = 2),24,100)*10000, labels = c("<$20k","$20k-$40k","$40k-$60k","$60k-$80k","$80k-$100k","$100k-$250k","$250k+"), ordered_result = TRUE)
  pattern <- "^(\\d{1,2}\\sto\\s)?(\\d{1,2})\\syears(\\sand\\sover)?" # replace age ranges with end of range
  levels(census$age) <- gsub(pattern, "\\2", levels(census$age), perl = TRUE)
  census$age <- as.numeric(levels(census$age))[census$age]
  census$age_range <- cut(census$age, breaks = c(17, seq(from = 34, to = 64, by = 10), 100), labels = c("18-34", "35-44", "45-54", "55-64", "65+"), ordered_result = TRUE)
  toCensus <- dplyr::left_join(toronto_cts, census)
  toCensus$Geo_Code <- sprintf("%.2f", as.numeric(toCensus$Geo_Code))
  save(toCensus, file = "data/toCensus.RData")
}
