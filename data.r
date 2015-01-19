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
  b$n_au = NA
  
  write.csv(b, bills, row.names = FALSE)
  
}

# parse bills

b = read.csv(bills, stringsAsFactors = FALSE)
b$ministry = grepl("nefnd", b$authors)

stopifnot(n_distinct(b$authors) == nrow(b))

j = unique(b$authors[ !b$ministry ])
a = data.frame()

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
    
    bio = xpathSApply(h, "//h1[@class='FyrirsognStorSv']/following-sibling::div[@class='AlmTexti']", xmlValue)
    url = xpathSApply(h, "//h1[@class='FyrirsognStorSv']/following-sibling::div[@class='AlmTexti']/a/@href")
    
    bio = unlist(strsplit(bio, "\\n"))
    bio = bio[ grepl("^\\d+", bio) ]
    
    # exclude single case: minister who cosponsored two bills, 2003-2007
    bio = bio[ !grepl("Jón Sigurðsson$", bio) ]
    url = url[ url != "/altext/cv/is/?nfaerslunr=1123" ]
    
    a = rbind(a, data.frame(authors = b$authors[ b$authors == i ], 
                            bio, url, stringsAsFactors = FALSE))
    
    if(length(url)) {
      
      b$n_au[ b$authors == i ] = length(url)
      cat(":", sprintf("%3.0f", length(url)), "sponsor(s)\n")
      
    } else {
      
      b$n_au[ b$authors == i ] = 0
      cat(": no sponsors\n")
      
    }
    
  }
    
}

write.csv(b, bills, row.names = FALSE)

b$legislature = NA
b$legislature[ b$session %in% 142:144 ] = "2013-2017" # election in April, bills from s. 142 start in June
b$legislature[ b$session %in% 137:141 ] = "2009-2013" # election in April, bills from s. 137 start in May
b$legislature[ b$session %in% 134:136 ] = "2007-2009" # election on May 12, bills from s. 134 start May 31
b$legislature[ b$session %in% 130:133 ] = "2003-2007" # election on May 10, no bills in s. 129, s. 130 starts in October
b$legislature[ b$session %in% 124:128 ] = "1999-2003" # election on May 8, bills from s. 124 start in June
b$legislature[ b$session %in% 119:123 ] = "1995-1999" # election on April 8, bills from s. 119 start in June

# print(table(b$legislature, b$n_au > 1, exclude = NULL))

# restrict further data collection to selected legislatures
b = subset(b, !is.na(legislature))

# parse sponsors and solve party transitions

stopifnot(a$authors %in% b$authors)
a = merge(a, b[, c("legislature", "authors") ], by = "authors")

a$bio = gsub("^\\d+\\.\\s+", "", a$bio)
a$bio = gsub("\\d+\\.\\sþm.\\s", "", a$bio)

# legislature 1995-1999: Alþýðubandalag (Ab) includes independents (og óháðir)
a$bio = gsub(", Óh$", ", Ab", a$bio)

# legislature 1995-1999: Social-Democratic alliance (A, Ab, JA, SK, Þ), Sf
a$bio = gsub(", (A|Ab|JA|SK|Þ)$", ", Sf", a$bio)

# legislature 1995-1999: Kristín Ástgeirsdóttir, shortly independent
a$bio[ a$url == "/altext/cv/is/?nfaerslunr=388" & 
         a$legislature == "1995-1999" ] = "Kristín Ástgeirsdóttir RV, Sf"

# legislature 1995-1999: Kristinn H. Gunnarsson, shortly independent
a$bio[ a$url == "/altext/cv/is/?nfaerslunr=386" & 
         a$legislature == "1995-1999" ] = "Kristinn H. Gunnarsson VF, Sf"

# legislature 2003-2007: Sigurlín Margrét Sigurðardóttir, shortly independent
a$bio[ a$url == "/altext/cv/is/?nfaerslunr=1041" & 
         a$legislature == "2003-2007" ] = "Sigurlín Margrét Sigurðardóttir SV, Fl"

# legislature 2003-2007: Kristinn H. Gunnarsson moved to Fl just before election
a$bio[ a$url == "/altext/cv/is/?nfaerslunr=386" & 
         a$legislature == "2003-2007" ] = "Kristinn H. Gunnarsson NV, F"

# legislature 2003-2007: Gunnar Örlygsson sponsored more bills as S
a$bio[ a$url == "/altext/cv/is/?nfaerslunr=657" & 
         a$legislature == "2003-2007" ] = "Gunnar Örlygsson SV, S"

# legislature 2003-2007: Valdimar L. Friðriksson sponsored more bills as Sf
a$bio[ a$url == "/altext/cv/is/?nfaerslunr=669" & 
         a$legislature == "2003-2007" ] = "Valdimar L. Friðriksson SV, Sf"

# legislature 2007-2009: Kristinn H. Gunnarsson, shortly independent
a$bio[ a$url == "/altext/cv/is/?nfaerslunr=386" & 
         a$legislature == "2007-2009" ] = "Kristinn H. Gunnarsson VF, Fl"

# legislature 2007-2009: Jón Magnússon sponsored more bills as Fl
a$bio[ a$url == "/altext/cv/is/?nfaerslunr=689" & 
         a$legislature == "2007-2009" ] = "Jón Magnússon RS, Fl"

# legislature 2009-2013: Ásmundur Einar Daðason sponsored more bills as F
a$bio[ a$url == "/altext/cv/is/?nfaerslunr=707" & 
         a$legislature == "2009-2013" ] = "Ásmundur Einar Daðason NV, F"

# legislature 2009-2013: Atli Gíslason sponsored more bills as U
a$bio[ a$url == "/altext/cv/is/?nfaerslunr=675" & 
         a$legislature == "2009-2013" ] = "Atli Gíslason SU, U"

# legislature 2009-2013: Þráinn Bertelsson sponsored more bills as Vg
a$bio[ a$url == "/altext/cv/is/?nfaerslunr=709" & 
         a$legislature == "2009-2013" ] = "Þráinn Bertelsson RN, Vg"

# legislature 2009-2013: Róbert Marshall sponsored more bills as Sf
a$bio[ a$url == "/altext/cv/is/?nfaerslunr=708" & 
         a$legislature == "2009-2013" ] = "Róbert Marshall SU, Sf"

# legislature 2009-2013: Lilja Mósesdóttir sponsored more bills as U
a$bio[ a$url == "/altext/cv/is/?nfaerslunr=711" & 
         a$legislature == "2009-2013" ] = "Lilja Mósesdóttir RS, U"

# legislature 2009-2013: Guðmundur Steingrímsson sponsored more bills (one more) as U
a$bio[ a$url == "/altext/cv/is/?nfaerslunr=704" & 
         a$legislature == "2009-2013" ] = "Guðmundur Steingrímsson NV, U"

# legislature 2009-2013: Borgarahreyfingin (Bhr) became Hreyfingin (Hr)
a$bio = gsub(", Bhr$", ", Hr", a$bio)

# detect sponsors with more than one party affiliation per legislature
d = group_by(unique(a[, c("url", "bio", "legislature") ]), url, legislature, bio) %>%
  arrange(url, legislature) %>%
  group_by(url, legislature) %>%
  mutate(n = n())

# check: single sponsor row per legislature
stopifnot(!nrow(filter(d, n > 1)))

# fix a few rows with missing data
a$bio[ a$bio == "Davíð Oddsson" ] = "Davíð Oddsson RV, S"           # 1995-1999; nfaerslunr=106
a$bio[ a$bio == "Halldór Ásgrímsson" ] = "Halldór Ásgrímsson AL, F" # 1995-1999; nfaerslunr=8

# scrape sponsors

if(!file.exists(sponsors)) {
  
  j = unique(a$url)
  s = data.frame()
  
  for(i in rev(j)) {
    
    cat(sprintf("%3.0f", which(j == i)), str_pad(i, 31, "right"))
    f = gsub("/altext/cv/is/\\?nfaerslunr=(\\d+)", "raw/mp-\\1.html", i)
    
    if(!file.exists(f))
      download.file(paste0(root, i), f, quiet = TRUE, mode = "wb")
    
    if(!file.info(f)$size) {
      
      file.remove(f)
      cat(": failed\n")
      
    }
    
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
      
      if(!file.info(p)$size) {
        
        cat(": failed to download photo")
        file.remove(p)
        
      }
      
    }
    
    s = rbind(s, data.frame(url = i, name, born, photo = p, stringsAsFactors = FALSE))
    cat("\n")
    
  }
  
  s$born[ s$url == "/altext/cv/is/?nfaerslunr=1120" ] = "1966" # Sandra Franks, 17. mars 1966.
  s$born[ s$url == "/altext/cv/is/?nfaerslunr=1049" ] = "1959" # Kolbrún Baldursdóttir, 23. mars 1959.
  
  # checked: no overlap in regex
  s$sex = NA
  s$sex[ grepl("sen$|son$", s$name) | grepl("^(Edward|Ellert|Geir|Halldór\\s|Helgi|Kristján|Magnús|Ólöf|Óttarr|Paul|Pétur|Ragnar|Róbert|Tómas|Þór\\s)", s$name) ] = "M"
  s$sex[ grepl("dóttir$", s$name) | grepl("^(Ásta|Dýrleif|Elín|Jónína|Katrín|Sandra|Þuríður)", s$name) ] = "F"
  
  # fix duplicates
  s = group_by(s, name) %>%
    mutate(suffix = 1:n(), duplicate = n() > 1) %>%
    mutate(duplicate = ifelse(duplicate, paste0(name, "-", suffix), name))
  
  cat("Solved", sum(s$name != s$duplicate), "duplicate(s)\n")
  s$name = s$duplicate  
  
  # no duplicates should show up
  rownames(s) = s$name

  write.csv(s[, c("url", "name", "sex", "born", "photo") ], 
            sponsors, row.names = FALSE)
  
}

s = read.csv(sponsors, stringsAsFactors = FALSE)
s$photo = gsub("photos/|\\.jpg", "", s$photo)

stopifnot(a$url %in% s$url)

# get seniority from CV listings
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

cv$url = gsub("cv/\\?", "cv/is/?", cv$url)
stopifnot(s$url %in% cv$url)

# merge sponsor details to seniority
s = left_join(s, cv, by = "url")

# panelize sponsor details
s = left_join(unique(a[, c("legislature", "url", "bio") ]),
              s, by = "url")

# extract constituency and party
# http://www.althingi.is/vefur/tmtal.html
s$bio = str_extract(s$bio, "\\w{2}, \\w+")
s$constituency = gsub("(.*), (.*)", "\\1", s$bio)
s$party = toupper(gsub("(.*), (.*)", "\\2", s$bio))
s$party[ s$party == "U" ] = "IND" # utan flokka
s$partyname = groups[ s$party ]
table(s$partyname, exclude = NULL)

# expand constituency names
s$constituency = c(
  "AL" = "Austurlandskjördæmi", # Austurlands(kjördæmis)
  "NA" = "Norðausturkjördæmi",
  "NE" = "Norðurlandskjördæmi_eystra", # Norðurlands(kjördæmis) eystra
  "NV" = "Norðurlandskjördæmi_vestra", # Norðurlands(kjördæmis) vestra
  "RN" = "Reykjaneskjördæmi", # Reyknesinga (Reykjaneskjördæmis)
  "RS" = "Reykjavíkurkjördæmi_suður",  # Reykjavíkurkjördæmi suður
  "RV" = "Ísland", # Reykvíkinga (national approportionment)
  "SL" = "Suðurlandskjördæmi", # Suðurlands(kjördæmis)
  "SU" = "Suðurkjördæmi",
  "SV" = "Suðvesturkjördæmi", # Suðvesturkjöræmi
  "VF" = "Vestfjarðakjördæmi", # Vestfirðinga (Vestfjarðakjördæmis)
  "VL" = "Vesturland")[ s$constituency ] # Vesturlands

# check for missing sponsors
for(i in b$authors[ !is.na(b$n_au) ]) {
  stopifnot(b$n_au[ b$authors == i ] == nrow(filter(a, authors == i)))
}

# kthxbye
