library(RCurl)
library(XML)
library(stringr)
library(optparse)

## Parts of this script was obtained from the public Git Repo walkerkq/musiclyrics

## This script has the ability to grab any year specified via these command line arguments.
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

songFrame <- data.frame() 
for (i in firstYear:lastYear) { 
	 # create the URL for each year
	 URL <- paste("http://en.wikipedia.org/wiki/Billboard_Year-End_Hot_100_singles_of_",i,sep="")
	 # parse the HTML
	 results <- htmlTreeParse(getURL(URL, followlocation=TRUE), useInternal=TRUE)
	 billboard_text <- xpathSApply(results, "//table[@class='wikitable sortable']//tr",xmlValue)
	 split_billboard_text <- str_split_fixed(billboard_text,"\n",3) 
	 billboard <- as.data.frame(cbind(split_billboard_text[2:101, ], rep(i,100)), stringsAsFactors=FALSE)
	 # row bind this year's data to all the data
	 songFrame <- rbind(songFrame, billboard) 
	 
}
colnames(songFrame) <- c("Rank", "Song", "Artist", "Year")

## prepare song and artist strings for website format
songFrame$Song <- gsub('\\"', "", songFrame$Song)
songFrame$Song <- tolower(gsub("[^[:alnum:] ]", "", songFrame$Song))
songFrame$Song <- gsub("\\'", "", iconv(songFrame$Song, to='ASCII//TRANSLIT')) # convert single quotes to ASCII

songFrame$Artist <- tolower(gsub("[^[:alnum:] ]", "", songFrame$Artist))
songFrame$Artist <- gsub("'e", "e", iconv(songFrame$Artist, to='ASCII//TRANSLIT')) # fix special accent charracters
songFrame$Artist<- gsub("'o", "o", songFrame$Artist)

# variables for the lyrics, and the source of the lyrics
songFrame$Lyrics <- ""
songFrame$Source <- ""

################### SCRAPE THE LYRICS FROM ONE OF MULTIPLE SOURCES ###################
### source: multiple.  1=songlyrics.com, 2=metorlyics.com, 3=lyricsmode.com
for (s in 1:length(songFrame$Song))  {

	lyrics <- "not set yet"

	# clean up the artist field to fit in the URL
	artist <- strsplit(songFrame$Artist[s], " featuring | feat | feat. | with | duet | and ")
	artist <- unlist(artist)[[1]]
	artist2 <- gsub("the ", "", artist)
	firstletter <- substring(artist2, 1, 1)

	# create URLs and mark Tags where the Lyrics sit
	songURL <- paste("http://songlyrics.com/",artist2,"/",songFrame$Song[s],"-lyrics",sep="")
	songTag <- c("//p[@id='songLyricsDiv']")

	metroURL <- paste("http://metrolyrics.com/",songFrame$Song[s],"-lyrics-",artist2,".html",sep="")
	metroTag <- c("//div[@id='lyrics-body-text']")

	modeURL <- paste("http://www.lyricsmode.com/lyrics/", firstletter, "/", artist2, "/", songFrame$Song[s], ".html", sep="")
	modeTag <- c("//p[@id='lyrics_text']")

	URLs <- c(songURL, metroURL,  modeURL)

	lyricTagLocation <- c( songTag, metroTag, modeTag)

	## Loop over the Possible URL's for each song
	for (b in 1:length(URLs)) {
		
		if(b!=3) URL <- tolower(gsub(" ", "-", URLs[b])) ## songs and artists are "-" delimited IE: jackson-browne-running-on-empty
		if(b==3) URL <- URLs[b]

		  tryCatch({ 
			#print(paste0(URLs[b], ",,", lyricTagLocation[b])) ## Test print to verify website and tag format are correct
			results <- htmlTreeParse(URL, useInternal=TRUE, isURL=TRUE)
			lyrics <- xpathSApply(results, lyricTagLocation[b], xmlValue) },
			error = function(x) { message(paste(s, "failed")) },
			finally={ if (!is.numeric(results)) { 
						 if (length(lyrics)!=0) { 
							  songFrame$Lyrics[s] <- lyrics[[1]]
							  message(paste(s, "success"))
							  songFrame$Source[s] <- b
							  break
						 }
					} 
			})
	}
}

# clean up the lyrics to alpha and lowercase, strip out "tab" and endline chars
songFrame$Lyrics <- gsub("\\\n|\\\t"," ",songFrame$Lyrics)
songFrame$Lyrics <- tolower(gsub("[^[:alnum:] ]", "", songFrame$Lyrics))

# convert failed lyrics to "NA"
songFrame$Lyrics <- gsub("not set yet", "NA", songFrame$Lyrics)  # Did not find Lyrics
# Error output from Songlyrics.com
songFrame$Lyrics <- gsub("we are not in a position to display these lyrics due to licensing restrictions sorry for the inconvenience", "NA", songFrame$Lyrics)
# Error output from MetroLyrics.com
songFrame$Lyrics <- gsub("Unfortunately, we aren't authorized to display these lyrics", "NA", songFrame$Lyrics)
# If song is Instrumental, there are no Lyrics
songFrame$Lyrics <- gsub("instrumental", "NA", songFrame$Lyrics)

write.csv(songFrame, paste0("lyrics_", firstYear,"-", lastYear, ".csv"), row.names=FALSE)

# some analytics for the percentage of missing songs. Can uncomment if needed.
missing <- round(length(songFrame[songFrame$Lyrics=="NA", 1])/length(songFrame[,1]), 4)*100
print(missing)



