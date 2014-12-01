library(ggplot2)
library(GGally)
library(grid)
library(httr)
library(network)
library(plyr)
library(qdap)
library(sna)
library(stringr)
library(tnet)
library(rgexf)
library(XML)

dir.create("data", showWarnings = FALSE)
dir.create("photos", showWarnings = FALSE)
dir.create("raw", showWarnings = FALSE)
dir.create("plots", showWarnings = FALSE)

root = "http://www.althingi.is"
bills = "data/bills.csv"
sponsors = "data/sponsors.csv"

colors = c(
  "VG"    = "#4DAF4A", # Vinstrihreyfingin – grænt framboð -- green
  "SAMF"  = "#E41A1C", # Samfylkingin-Jafnaðarmannaflokkur -- red
  "BJÖRT" = "#984EA3", # Björt framtíð                     -- purple
  "FRJÁL" = "#80B1D3", # Frjálslyndi flokkurinn            -- light blue
  "FRAM"  = "#B3DE69", # Framsóknarflokkurinn              -- light green
  "SJÁLF" = "#377EB8", # Sjálfstæðisflokkurinn             -- blue
  "PÍRAT" = "#444444", # Píratar                           -- dark grey
  "HREY"  = "#01665E", # Borgarahreyfingin / Hreyfingin    -- teal
  "IND"   = "#AAAAAA"
)
order = names(colors)

source("data.r")

plot = TRUE
gexf = TRUE

for(ii in rev(unique(na.omit(b$legislature)))) {
  
  cat(ii)
  data = subset(b, legislature == ii & n_au > 1)
  
  cat(":", nrow(data), "cosponsored documents, ")
  
  edges = rbind.fill(lapply(data$sponsors, function(d) {
    
    w = unlist(strsplit(d, ";"))
    d = s$name[ s$url %in% w ]
    
    d = subset(expand.grid(d, d), Var1 != Var2)
    # d = subset(expand.grid(Var1 = d[1], Var2 = d[-1], stringsAsFactors = FALSE), Var1 != Var2)
    d = unique(apply(d, 1, function(x) paste0(sort(x), collapse = "__")))
    
    if(length(d))
      return(data.frame(d, w = length(w) - 1)) # number of cosponsors
    else
      return(data.frame())
    
  }))
  
  # raw edge counts
  count = table(edges$d)
  
  # Newman-Fowler weights (weighted quantity of bills cosponsored)
  edges = aggregate(w ~ d, function(x) sum(1 / x), data = edges)
  
  # raw counts
  edges$count = as.vector(count[ edges$d ])
  
  edges = data.frame(i = gsub("(.*)__(.*)", "\\1", edges$d),
                     j = gsub("(.*)__(.*)", "\\2", edges$d),
                     w = edges$w, n = edges[, 3])
  
  cat(nrow(edges), "edges, ")
  
  # network
  
  n = network(edges[, 1:2 ], directed = FALSE)
  n %n% "title" = paste("Althing", paste0(range(unique(substr(data$date, 1, 4))), collapse = " to "))
  n %n% "n_bills" = nrow(data)
  
  n %n% "n_sponsors" = table(subset(b, legislature == ii)$n_au)
  
  cat(network.size(n), "nodes")
  
  rownames(s) = s$name
  n %v% "url" = as.character(s[ network.vertex.names(n), "url" ])
  n %v% "name" = as.character(s[ network.vertex.names(n), "name" ])
  n %v% "sex" = as.character(s[ network.vertex.names(n), "sex" ])
  n %v% "born" = as.numeric(substr(s[ network.vertex.names(n), "born" ], 1, 4))
  n %v% "party" = s[ network.vertex.names(n), "party" ]
  n %v% "partyname" = s[ network.vertex.names(n), "partyname" ]
  # mandate years done before start year of legislature
  s$nyears = sapply(s$mandate, function(x) {
    sum(unlist(strsplit(x, ";")) <= as.numeric(substr(ii, 1, 4)))
  })
  n %v% "nyears" = as.numeric(s[ network.vertex.names(n), "nyears" ])
  n %v% "photo" = as.character(s[ network.vertex.names(n), "photo" ])
  
  network::set.edge.attribute(n, "source", as.character(edges[, 1]))
  network::set.edge.attribute(n, "target", as.character(edges[, 2]))
  
  network::set.edge.attribute(n, "weight", edges[, 3])
  network::set.edge.attribute(n, "count", edges[, 4])
  network::set.edge.attribute(n, "alpha",
                              as.numeric(cut(n %e% "count", c(1:4, Inf),
                                             include.lowest = TRUE)) / 5)
  
  # modularity
  
  nn = graph.edgelist(as.matrix(edges[, 1:2 ]), directed = FALSE)
  E(nn)$weight = edges[, 3]
  
  i = s[ V(nn)$name, "party" ]
  i[ i %in% c("IND") ] = NA # ignoring: unaffiliateds
  
  nn = nn - which(is.na(i))
  i = as.numeric(factor(i[ !is.na(i) ]))
  
  n %n% "modularity" = modularity(nn, membership = i, weights = E(nn)$weight)
  cat("\nModularity:", round(n %n% "modularity", 2))
  
  walktrap = lapply(1:50, function(x) walktrap.community(nn, steps = x))
  
  # max. partition
  maxwalks = order(sapply(walktrap, modularity), decreasing = TRUE)[1]
  walktrap = walktrap[[ maxwalks ]]
  
  n %n% "modularity_walktrap" = modularity(walktrap)
  cat(" Walktrap:", round(n %n% "modularity_walktrap", 2))
  
  louvain = multilevel.community(nn)
  
  n %n% "modularity_louvain" = modularity(louvain)
  cat(" Louvain:", round(n %n% "modularity_louvain", 2))
  
  # weighted adjacency matrix to tnet
  tnet = as.tnet(as.sociomatrix(n, attrname = "weight"), type = "weighted one-mode tnet")
  
  # weighted degree and distance
  wdeg = as.data.frame(degree_w(tnet, measure = "degree"))
  dist = distance_w(tnet)
  wdeg$distance = NA
  wdeg[ attr(dist, "nodes"), ]$distance = colMeans(dist, na.rm = TRUE)
  wdeg = cbind(wdeg, clustering_local_w(tnet)[, 2])
  names(wdeg) = c("node", "degree", "distance", "clustering")
  
  n %v% "degree" = wdeg$degree
  n %n% "degree" = mean(wdeg$degree, na.rm = TRUE)
  cat("\nDegree:", round(n %n% "degree", 2))
  
  n %v% "distance" = wdeg$distance
  n %n% "distance" = mean(wdeg$distance, na.rm = TRUE)
  cat(" Distance:", round(n %n% "distance", 2))
  
  n %v% "clustering" = wdeg$clustering    # local
  n %n% "clustering" = clustering_w(tnet) # global
  cat(" Clustering:", round(n %n% "clustering", 2))
  
  i = colors[ s[ n %e% "source", "party" ] ]
  j = colors[ s[ n %e% "target", "party" ] ]
  
  party = as.vector(i)
  party[ i != j ] = "#AAAAAA"
  
  print(table(n %v% "party", exclude = NULL))
  stopifnot(all(unique(n %v% "party") %in% names(colors)))
  
  # number of bills cosponsored
  nb = unlist(strsplit(data$sponsors, ";"))
  nb = sapply(n %v% "url", function(x) {
    sum(nb == x) # ids are 5-length numbers
  })
  n %v% "n_bills" = as.vector(nb)

  if(plot) {

    q = unique(quantile(n %v% "degree")) # safer
    n %v% "size" = as.numeric(cut(n %v% "degree", q, include.lowest = TRUE))
    
    g = suppressWarnings(ggnet(n, size = 0, segment.alpha = 1/2, # mode = "kamadakawai",
                               segment.color = party) +
                           geom_point(alpha = 1/3, aes(size = n %v% "size", color = n %v% "party")) +
                           geom_point(alpha = 1/2, aes(size = min(n %v% "size"), color = n %v% "party")) +
                           scale_size_continuous(range = c(6, 12)) +
                           scale_color_manual("", values = colors, breaks = order) +
                           theme(legend.key.size = unit(1, "cm"),
                                 legend.text = element_text(size = 16)) +
                           guides(size = FALSE, color = guide_legend(override.aes = list(alpha = 1/3, size = 6))))
    
    print(g)
    
    ggsave(paste0("plots/net_is", ii, ".pdf"), 
           g + theme(legend.key = element_blank()),
           width = 10, height = 9)
    ggsave(paste0("plots/net_is", ii, ".jpg"),
           g + theme(legend.position = "none"),
           width = 9, height = 9, dpi = 150)
    
  }
  
  assign(paste0("net_is", substr(ii, 1, 4)), n)
  assign(paste0("edges_is", substr(ii, 1, 4)), edges)
  assign(paste0("bills_is", substr(ii, 1, 4)), data)
  
  # gexf
  if(gexf) {
    
    rgb = t(col2rgb(colors[ names(colors) %in% as.character(n %v% "party") ]))
    mode = "fruchtermanreingold"
    meta = list(creator = "rgexf",
                description = paste(mode, "placement", nrow(data), "bills"),
                keywords = "parliament, iceland")
    
    node.att = data.frame(url = gsub("/altext/cv/is/\\?nfaerslunr=", "", n %v% "url"), # simplify URL
                          party = n %v% "partyname",
                          bills = n %v% "n_bills",
                          distance = round(n %v% "distance", 1),
                          photo = gsub("photos/|\\.jpg", "", n %v% "photo"),
                          stringsAsFactors = FALSE)
    
    people = data.frame(id = as.numeric(factor(network.vertex.names(n))),
                        label = network.vertex.names(n),
                        stringsAsFactors = FALSE)
    
    relations = data.frame(
      source = as.numeric(factor(n %e% "source", levels = levels(factor(people$label)))),
      target = as.numeric(factor(n %e% "target", levels = levels(factor(people$label)))),
      weight = round(n %e% "weight", 2), count = n %e% "count")
    relations = na.omit(relations)
    
    # check all weights are positive after rounding
    stopifnot(all(relations$weight > 0))
    
    nodecolors = lapply(n %v% "party", function(x)
      data.frame(r = rgb[x, 1], g = rgb[x, 2], b = rgb[x, 3], a = .5))
    nodecolors = as.matrix(rbind.fill(nodecolors))
    
    # node placement
    position = do.call(paste0("gplot.layout.", mode),
                       list(as.matrix.network.adjacency(n), NULL))
    position = as.matrix(cbind(round(position, 1), 1))
    colnames(position) = c("x", "y", "z")
    
    write.gexf(nodes = people, nodesAtt = node.att,
               edges = relations[, 1:2 ], edgesWeight = relations[, 3],
               nodesVizAtt = list(position = position, color = nodecolors,
                                  size = round(n %v% "degree", 1)),
               # edgesVizAtt = list(size = relations[, 4]),
               defaultedgetype = "undirected", meta = meta,
               output = paste0("net_is", ii, ".gexf"))
    
  }
  
}

if(gexf)
  zip("net_is.zip", dir(pattern = "^net_is\\d{4}-\\d{4}\\.gexf$"))

save(list = ls(pattern = "^(net|edges|bills)_is\\d{4}$"), file = "data/net_is.rda")

# kthxbye

