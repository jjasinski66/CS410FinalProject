# CS410FinalProject
# songscrape2.R

Documentation writing for project linked below:

https://github.com/jjasinski66/CS410FinalProject/blob/master/LYRICS%20DATABASE%20TOOL%20FOR%20EXPLORATION%20AND%20DISCOVERY.pdf

## This script will automatically get the Billboard Top 100 for any year or sequence of years the user specifies.

  - The script takes two command line arguments 
    - beginning, The First year to start searching
    - ending,     The last year to search
  - This script requires R and utilizes the libraries (RCurl, XML, stringer, optparse)
  - Example command: `Rscript songscrape2.R --beginning=1984 --ending=1984`
    
## The Script acts in three different parts.

  - Part 1: Get the song list from the Wikipedia page for the Billboard Top 100 for any year.
    - The script will retrieve and parse the wiki page for the specified year and create a dataframe with the Rank, Title, Artist, and Year of the song.
    - Each Years hits are pasted onto the data frame using the rbind command.
    
  - Part 2: Use the Artist and Song information to lookup the song from one of three open websites.
    - note: I wanted to use this method for two reasons.
      - The Lack of required Hash key or login for any other API's makes this more user friendly and anonymous
      - Open websites make the dataset easily retrievable by anyone.
      - The XML used by these websites is consistent, and the tags necessary to find the lyrics are simpler to program.
    - The three websites used, metorlyics.com, songlyrics.com, lyricsmode.com have a huge repository of song lyrics. Between the three of them, the chance of finding a song's lyrics is greatly increased.
    - The script then loops over the data frame using the artist and song title to create a suspected url of the song in question.
    - The script they tries to retrieve the lyrics from a site, if it fails, it goes onto the next site, and so on.
    - Once a lyric is found, the lyrics are added to the data frame.
   
  - Part 3: Text processing on the lyrics.
    - Since the lyrics themselves are scraped from a web html, There are many non word characters that need to be cleaned. 
    - Also, special characters need to be converted or eliminated.
    - Endlines, and tab characters are replaced with empty strings.
    - All characters are converted to lowercase and normalized to UTF-8.
    - The error messages from websites for copyrighted, or missing lyrics are replaced with NA.
    - Lastly Instrumental hits have no lyrics, and are therefore converted to NA as well.
    - Finally the entire data frame is written to a csv for more convenient transportation.
      - note: The script will also display the percentage of songs that failed to get lyrics from any of the three sites.
      
  - Future iterations of this scraper can merge lyrics from multiple sites for a more consistent data set.
  
  - Included in this repo is the set from 1965 to 2017
