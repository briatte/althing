# scrape bills (Lagafrumvörp); leaving resolutions (Þingsályktunartillögur) out
# URL: http://www.althingi.is/vefur/thingmalalisti.html?cmalteg=l

root = "http://www.althingi.is"
bills = "data/bills.csv"
sponsors = "data/sponsors.csv"

if(!file.exists(bills)) {
  
  b = data.frame()
  for(i in 144:119) { # accepts down to 20 (1907)
    
    cat(sprintf("%3.0f", i))
    
    file = paste0("raw/bills-", i, ".html")
    
    if(!file.exists(file))
      download.file(paste0(root, "/vefur/thingmalalisti.html?cmalteg=l&orderby=&validthing=", i), file,
                    quiet = TRUE, mode = "wb")
    
    h = htmlParse(file, encoding = "UTF-8")
    
    ref = xpathSApply(h, "//table[@id='t_malalisti']//tr/td[1]", xmlValue)
    if(length(ref)) {
      
      date = xpathSApply(h, "//table[@id='t_malalisti']//tr/td[2]", xmlValue)
      
      name = xpathSApply(h, "//table[@id='t_malalisti']//tr/td[3]", xmlValue)
      url = xpathSApply(h, "//table[@id='t_malalisti']//tr/td[3]/a/@href")
      
      author = xpathSApply(h, "//table[@id='t_malalisti']//tr/td[4]", xmlValue)
      authors = xpathSApply(h, "//table[@id='t_malalisti']//tr/td[4]/a/@href")
      
      b = rbind(b, data.frame(session = i, ref, date, name, url, author, authors,
                              stringsAsFactors = FALSE))
      
      cat(":", sprintf("%5.0f", nrow(b)), "total bills\n")
      
    } else {
      
      cat(": no bills\n")
      
    }
    
  }
  
  b$author = str_clean(b$author)
  b$authors = str_trim(b$authors)
  b$date = as.Date(strptime(b$date, "%d.%m.%Y"))
  b$text = NA
  b$sponsors = NA
  
  write.csv(b, bills, row.names = FALSE)
  
}

b = read.csv(bills, stringsAsFactors = FALSE)

b$ministry = grepl("nefnd", b$authors)

j = unique(b$authors[ !b$ministry & is.na(b$sponsors) ])

for(i in rev(j)) {
  
  cat(sprintf("%4.0f", which(j == i)), i)
  
  file = gsub("/dba-bin/flms\\.pl\\?lthing=(\\d+)&skjalnr=(\\d+)", "raw/bill-\\1-\\2.html", i)
  
  if(!file.exists(file))
    try(download.file(paste0(root, i), file, quiet = TRUE, mode = "wb"), silent = TRUE)
  
  if(!file.info(file)$size) {
    
    file.remove(file)
    cat(": failed\n")
    
  } else {

    h = htmlParse(file, encoding = "UTF-8")
    
    text = xpathSApply(h, "//h1[@class='FyrirsognStorSv']/following-sibling::div[@class='AlmTexti']", xmlValue)
    urls = xpathSApply(h, "//h1[@class='FyrirsognStorSv']/following-sibling::div[@class='AlmTexti']/a/@href")
    
    b$text[ b$authors == i ] = str_clean(text)
    
    if(length(urls)) {
      
      b$sponsors[ b$authors == i ] = paste0(urls, collapse = ";")
      cat(":", 1 + str_count(b$sponsors[ b$authors == i ], ";"), "sponsor(s)\n")
      
    } else {
      
      b$sponsors[ b$authors == i ] = ""
      cat(": no sponsors\n")
      
    }
    
  }
    
}

b$text = gsub("(.*) löggjafarþingi\\. ", "", b$text)
b$text = gsub("(.*) Gert (.*)", "\\1", b$text)
b$text[ grepl("^Gert (.*)\\.$", b$text) ] = ""

write.csv(b, bills, row.names = FALSE)

b$legislature = NA
b$legislature[ b$session %in% 142:144 ] = "2013-2017" # election in April, bills from s. 142 start in June
b$legislature[ b$session %in% 137:141 ] = "2009-2013" # election in April, bills from s. 137 start in May
b$legislature[ b$session %in% 134:136 ] = "2007-2009" # election on May 12, bills from s. 134 start May 31
b$legislature[ b$session %in% 130:133 ] = "2003-2007" # election on May 10, no bills in s. 129, s. 130 starts in October
b$legislature[ b$session %in% 124:128 ] = "1999-2003" # election on May 8, bills from s. 124 start in June
b$legislature[ b$session %in% 119:123 ] = "1995-1999" # election on April 8, bills from s. 119 start in June

# restrict further data collection to selected legislatures
b = subset(b, !is.na(legislature))

b$n_au = 1 + str_count(b$sponsors, ";")
b$n_au[ b$ministry ] = NA

# print(table(b$legislature, b$n_au > 1, exclude = NULL))

# scrape sponsors

if(!file.exists(sponsors)) {
  
  a = na.omit(unique(unlist(strsplit(b$sponsors, ";"))))
  s = data.frame()
  
  for(i in rev(a)) {
    
    cat(sprintf("%3.0f", which(a == i)))
    f = gsub("/altext/cv/is/\\?nfaerslunr=(\\d+)", "raw/mp-\\1.html", i)
    
    if(!file.exists(f))
      download.file(paste0(root, i), f, quiet = TRUE, mode = "wb")
    
    if(!file.info(f)$size)
      file.remove(f)
    
    if(file.exists(f)) {
      
      h = htmlParse(f, encoding = "UTF-8")
      
      name = xpathSApply(h, "//meta[@property='og:title']/@content")
      name = str_trim(gsub("Æviágrip: ", "", name))
      
      photo = xpathSApply(h, "//img[contains(@src, 'thingmenn-cache') and @width='220']/@src")
      
      born = "//p[starts-with(text(), 'F.') or starts-with(text(), ' F.') or starts-with(text(), 'Fædd')]"
      born = xpathSApply(h, born, xmlValue)
      born = ifelse(!length(born), NA, str_extract(born, "[0-9]{4}"))
            
      if(!length(photo)) {
        
        p = NA
        
      } else {
        
        p = gsub("html$", "jpg", gsub("raw/mp-", "photos/", f))
        
        if(!file.exists(p))
          download.file(paste0(root, photo), p, quiet = TRUE, mode = "wb")
        
        if(!file.info(p)$size)
          file.remove(p)
        
      }
      
      cat(":", str_pad(i, 30, "right"), name, "\n")
      s = rbind(s, data.frame(url = i, name, born, photo = p, stringsAsFactors = FALSE))
      
    }
    else
      cat(": failed\n")
    
  }
  
  s$born[ s$url == "/altext/cv/is/?nfaerslunr=1120" ] = "1966" # Sandra Franks, 17. mars 1966.
  s$born[ s$url == "/altext/cv/is/?nfaerslunr=1049" ] = "1959" # Kolbrún Baldursdóttir, 23. mars 1959.
  
  s$sex = NA
  s$sex[ grepl("sen$|son$", s$name) | grepl("^(Edward|Ellert|Geir|Halldór|Kristján|Magnús|Ólöf|Óttarr|Paul|Pétur|Ragnar|Róbert|Tómas|Þór)", s$name) ] = "M"
  s$sex[ grepl("dóttir$", s$name) | grepl("^(Ásta|Dýrleif|Elín|Helgi|Jónína|Katrín|Sandra|Þuríður)", s$name) ] = "F"
  
  # fix duplicates (written after downloading all sponsors, session 20-144)
  # reshape::sort_df(subset(s, name %in% s$name[duplicated(s$name)]), "name")
  
  # ‘Alfreð Gíslason’
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=17" ] = "Alfreð Gíslason-1"
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=17" ] = "Alfreð Gíslason-2"
  # ‘Árni Gunnarsson’
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=36" ] = "Árni Gunnarsson-1"
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=1055" ] = "Árni Gunnarsson-2"
  # ‘Bjarni Benediktsson’
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=64" ] = "Bjarni Benediktsson-1"
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=652" ] = "Bjarni Benediktsson-2"
  # ‘Björn Jónsson’
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=83" ] = "Björn Jónsson-1"
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=84" ] = "Björn Jónsson-2"
  # ‘Björn Kristjánsson’
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=85" ] = "Björn Kristjánsson-1"
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=86" ] = "Björn Kristjánsson-2"
  # ‘Björn Líndal’
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=87" ] = "Björn Líndal-1"
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=768" ] = "Björn Líndal-2"
  # ‘Einar Jónsson’
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=127" ] = "Einar Jónsson-1"
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=128" ] = "Einar Jónsson-2"
  # ‘Gunnar Ólafsson’
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=209" ] = "Gunnar Ólafsson-1"
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=1061" ] = "Gunnar Ólafsson-2"
  # ‘Halldór Ásgrímsson’
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=220" ] = "Halldór Ásgrímsson-1"
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=8" ] = "Halldór Ásgrímsson-2"
  # ‘Hermann Jónasson’
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=248" ] = "Hermann Jónasson-1"
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=249" ] = "Hermann Jónasson-2"
  # ‘Jón Gunnarsson’
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=659" ] = "Jón Gunnarsson-1"
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=688" ] = "Jón Gunnarsson-2"
  # ‘Jón Jónsson’
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=319" ] = "Jón Jónsson-1"
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=320" ] = "Jón Jónsson-2"
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=322" ] = "Jón Jónsson-3"
  # ‘Jón Kjartansson’
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=323" ] = "Jón Kjartansson-1"
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=324" ] = "Jón Kjartansson-2"
  # ‘Jón Magnússon’
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=326" ] = "Jón Magnússon-1"
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=689" ] = "Jón Magnússon-2"
  # ‘Jón Ólafsson’
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=327" ] = "Jón Ólafsson-1"
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=328" ] = "Jón Ólafsson-2"
  # ‘Jón Sigurðsson’
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=335" ] = "Jón Sigurðsson-1"
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=336" ] = "Jón Sigurðsson-2"
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=1123" ] = "Jón Sigurðsson-3"
  # ‘Kjartan Ólafsson’
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=378" ] = "Kjartan Ólafsson-1"
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=379" ] = "Kjartan Ólafsson-2"
  # ‘Kolbrún Jónsdóttir’
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=382" ] = "Kolbrún Jónsdóttir-1"
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=873" ] = "Kolbrún Jónsdóttir-2"
  # ‘Magnús Jónsson’
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=417" ] = "Magnús Jónsson-1"
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=418" ] = "Magnús Jónsson-2"
  # ‘Ólafur Björnsson’
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=435" ] = "Ólafur Björnsson-1"
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=901" ] = "Ólafur Björnsson-2"
  # ‘Pétur Sigurðsson’
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=486" ] = "Pétur Sigurðsson-1"
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=915" ] = "Pétur Sigurðsson-2"
  # ‘Stefán Stefánsson’
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=546" ] = "Stefán Stefánsson-1"
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=545" ] = "Stefán Stefánsson-2"
  # ‘Tryggvi Gunnarsson’
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=581" ] = "Tryggvi Gunnarsson-1"
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=969" ] = "Tryggvi Gunnarsson-2"
  # ‘Valgerður Gunnarsdóttir’ 
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=976" ] = "Valgerður Gunnarsdóttir-1"
  s$name[ s$url == "/altext/cv/is/?nfaerslunr=1175" ] = "Valgerður Gunnarsdóttir-2"
  
  write.csv(s, sponsors, row.names = FALSE)
  
}

s = read.csv(sponsors, stringsAsFactors = FALSE)

# get political party from CV list
cv = data.frame()
for(i in c("A", "%C1", "B", "D", "E", "F", "G", "H", "I", "%CD", "J", "K", 
           "L", "M", "N", "O", "%D3", "P", "R", "S", "T", "U", "V", "W", 
           "%DE", "%D6")) {
  
  f = paste0("raw/cvs-", i, ".html")
  
  if(!file.exists(f))
    download.file(paste0(root, "/altext/cv/?cstafur=", i, "&bnuverandi=0"),
                  f, quiet = TRUE, mode = "wb")
  
  h = htmlParse(f, encoding = "UTF-8")
  u = xpathSApply(h, "//a[contains(@href, 'nfaerslunr')]/@href")
  m = xpathSApply(h, "//a[contains(@href, 'nfaerslunr')]/..", xmlValue)
  m = str_clean(gsub("(.*)(Al|V)þm.", "", m))
  cv = rbind(cv, data.frame(url = u, mandate = m, stringsAsFactors = FALSE))
  
}

cv$url = gsub("cv/\\?", "cv/is/?", cv$url)
cv = subset(cv, url %in% s$url)

# extract main political parties
cv$party = str_extract(cv$mandate, "V(instri|g)|Samf|jafna|Sjálf|Fram|Frjál|Hrey|Pírat|Björt|Samtök|Alþ(ý|fl|b)")
cv$party[ cv$party == "Vinstri" ] = "Vg"

# simplification: various codes before 1999, coded differently depending on MPs
cv$party[ grepl("Alþ|jafna|Samtök", cv$party) ] = "Samf"

table(cv$party)

cv$party = toupper(cv$party)
cv$party[ is.na(cv$party)] = "IND"

cv$partyname = NA
cv$partyname[ cv$party == "IND" ] = "independent"
cv$partyname[ cv$party == "BJÖRT" ] = "Björt framtíð"
cv$partyname[ cv$party == "FRAM" ] = "Framsóknarflokkurinn"
cv$partyname[ cv$party == "FRJÁL" ] = "Frjálslyndi flokkurinn"
cv$partyname[ cv$party == "HREY" ] = "Hreyfingin"
cv$partyname[ cv$party == "PÍRAT" ] = "Píratar"
cv$partyname[ cv$party == "SAMF" ] = "Samfylkingin-Jafnaðarmannaflokkur" # and other Social-Democratic parties before 1999
cv$partyname[ cv$party == "SJÁLF" ] = "Sjálfstæðisflokkurinn"
cv$partyname[ cv$party == "VG" ] = "Vinstrihreyfingin – grænt framboð"

# expand mandate to years
cv$mandate = sapply(cv$mandate, function(y) {
  x = as.numeric(unlist(str_extract_all(y, "[0-9]{4}")))
  if(length(x) %% 2 == 1 & grepl("síðan", y)) # "since"
    x = c(x, 2014)
  else if(length(x) %% 2 == 1)
    x = c(x, x[ length(x) ])
  x = matrix(x, ncol = 2, byrow = TRUE)   # each row is a pseudo-term (some years are unique years)
  x = apply(x, 1, paste0, collapse = "-") # each value is a sequence
  x = lapply(x, function(x) {
    x = as.numeric(unlist(strsplit(x, "-")))
    x = seq(x[1], x[2])
  })
  paste0(sort(unique(unlist(x))), collapse = ";") # all years included in mandate(s)
})

s = merge(s, cv[, c("url", "party", "partyname", "mandate") ], by = "url")

# print(table(s$partyname, exclude = NULL))

# final processing of URLs
s$url = gsub("/altext/cv/is/\\?nfaerslunr=", "", s$url)
b$sponsors = gsub("/altext/cv/is/\\?nfaerslunr=", "", b$sponsors)
s$photo = gsub("photos/|\\.jpg", "", s$photo)

# kthxbye
