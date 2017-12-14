library(RCurl)
library(XML)
library(stringr)
library(optparse)

option_list = list(
  make_option(c("-b", "--beginning"), type="numeric", default=1960, 
              help="Starting Year for the Search", metavar="numeric"),
  make_option(c("-e", "--ending"), type="numeric", default=2016, 
              help="Ending Year for the Search", metavar="numeric")
);  

opt_parser = OptionParser(option_list=option_list);
opt = parse_args(opt_parser);

firstYear <- opt$beginning
lastYear <- opt$ending

################### GET SONG NAMES FROM WIKIPEDIA ###################
#### source: wikipedia.org

allSongs <- data.frame() 
for (i in firstYear:lastYear) { 
     # create the URL for each year
     URL <- paste("http://en.wikipedia.org/wiki/Billboard_Year-End_Hot_100_singles_of_",i,sep="")
     # parse the HTML
     results <- htmlTreeParse(getURL(URL, followlocation=TRUE), useInternal=TRUE)
     billboard_text <- xpathSApply(results, "//table[@class='wikitable sortable']//tr",xmlValue)
     split_billboard_text <- str_split_fixed(billboard_text,"\n",3) 
     billboard <- as.data.frame(cbind(split_billboard_text[2:101, ], rep(i,100)), stringsAsFactors=FALSE)
     # row bind this year's data to all the data
     allSongs <- rbind(allSongs, billboard) 
     
}
colnames(allSongs) <- c("Rank", "Song", "Artist", "Year")
lyricfail <- "We do not have the lyrics for"

## prepare song and artist strings for website format
allSongs$Song <- gsub('\\"', "", allSongs$Song)
allSongs$Song <- tolower(gsub("[^[:alnum:] ]", "", allSongs$Song))
allSongs$Song <- gsub("\\'", "", iconv(allSongs$Song, to='ASCII//TRANSLIT')) # convert single quotes to ASCII

allSongs$Artist <- tolower(gsub("[^[:alnum:] ]", "", allSongs$Artist))
allSongs$Artist <- gsub("'e", "e", iconv(allSongs$Artist, to='ASCII//TRANSLIT')) # fix special accent charracters
allSongs$Artist<- gsub("'o", "o", allSongs$Artist)

# variables for the lyrics, and the source of the lyrics
allSongs$Lyrics <- ""
allSongs$Source <- ""

################### SCRAPE THE LYRICS FROM ONE OF MULTIPLE SOURCES ###################
### source: multiple. 1=metorlyics.com, 2=songlyrics.com, 3=lyricsmode.com
for (s in 1:length(allSongs$Song))  {
     
     lyrics <- "Not set yet."
     
     # clean up the artist field to fit in the URL
     artist <- strsplit(allSongs$Artist[s], " featuring | feat | feat. | with | duet | and ")
     artist <- unlist(artist)[[1]]
     artist2 <- gsub("the ", "", artist)
     firstletter <- substring(artist2, 1, 1)
     
     # create URLs
     metroURL <- paste("http://metrolyrics.com/",allSongs$Song[s],"-lyrics-",artist2,".html",sep="")
     songURL <- paste("http://songlyrics.com/",artist2,"/",allSongs$Song[s],"-lyrics",sep="")
     modeURL <- paste("http://www.lyricsmode.com/lyrics/", firstletter, "/", artist2, "/", allSongs$Song[s], ".html", sep="")
     
     URLs <- c(metroURL, songURL, modeURL)
     
     lyricTagLocation <- c("//div[@id='lyrics-body-text']", 
                    "//p[@id='songLyricsDiv']", 
                    "//p[@id='lyrics_text']")
     
     # Tag to grab lyrics only, and omit nested ad's
     metroClassTag <- "//p[@class='verse']"

     for (b in 1:length(URLs)) {
          allSongs$Lyrics[s] <- "Not set yet."
          
          results <- 15 # use numeric value for success flag
          
          if(b!=3) URL <- tolower(gsub(" ", "-", URLs[b]))
          if(b==3) URL <- URLs[b]
          
          tryCatch({ 
               results <- htmlTreeParse(URL, useInternal=TRUE, isURL=TRUE)
               if ( b == 1)
               { lyricsRaw <- xpathSApply(results, metroClassTag, xmlValue)
                 lyrics <- paste( unlist(lyricsRaw), collapse='')
                 } 
               else
                   { lyrics <- xpathSApply(results, lyricTagLocation[b], xmlValue)}
               },
               error = function(x) { 
                    message(paste(s, "failed", allSongs$Song[s])) },
               finally={ 
                    if (!is.numeric(results)) {
                         #print(grepl(lyricfail, lyrics))
                         #print(lyrics)
                         ## Checks for dummy placement within the page for missing lyrics, and tries the next provider.
                         if (length(lyrics) != 0){
                              if ((nchar(lyrics) != 0) && !grepl(lyricfail, lyrics)) {
                                  allSongs$Lyrics[s] <- lyrics[[1]]
                                  message(paste(s, "success", allSongs$Song[s]))
                                  allSongs$Source[s] <- b
                                  break
                             }
                         }
                    } 
               })
     }
}

# clean up the lyrics to alpha and lowercase
allSongs$Lyrics <- gsub("\\\n|\\\t"," ",allSongs$Lyrics)
allSongs$Lyrics <- tolower(gsub("[^[:alnum:] ]", "", allSongs$Lyrics))
missing <- round(length(allSongs[allSongs$Lyrics=="not set yet", 1])/length(allSongs[,1]), 4)*100

# convert failed lyrics and "Instrumental Songs" to "NA"
allSongs$Lyrics <- gsub("not set yet", "NA", allSongs$Lyrics)
allSongs$Lyrics <- gsub("we are not in a position to display these lyrics due to licensing restrictions sorry for the inconvenience", "NA", allSongs$Lyrics)
allSongs$Lyrics <- gsub("instrumental", "NA", allSongs$Lyrics)

write.csv(allSongs, paste0("lyrics_", firstYear,"-", lastYear, ".csv"), row.names=FALSE, quote=FALSE)
allSongs <- read.csv(paste0("lyrics_", firstYear,"-", lastYear, ".csv"), stringsAsFactors=FALSE)



