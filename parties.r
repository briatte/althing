# party colors

colors = c(
  "VG"    = "#4DAF4A", # Vinstrihreyfingin – grænt framboð -- green
  "PÍRAT" = "#444444", # Píratar                           -- dark grey
  "SAMF"  = "#E41A1C", # Samfylkingin-Jafnaðarmannaflokkur -- red
  "FRAM"  = "#B3DE69", # Framsóknarflokkurinn              -- light green
  "BJÖRT" = "#984EA3", # Björt framtíð                     -- purple
  "HREY"  = "#01665E", # Borgarahreyfingin / Hreyfingin    -- teal
  "FRJÁL" = "#80B1D3", # Frjálslyndi flokkurinn            -- light blue
  "SJÁLF" = "#377EB8", # Sjálfstæðisflokkurinn             -- blue
  "IND"   = "#AAAAAA"
)

# ParlGov Left/Right scores

scores = c(
  "VG"    = 1.2,
  "PÍRAT" = 2.6,
  "SAMF"  = 4.1,
  "FRAM"  = 5,
  "BJÖRT" = 6,
  "HREY"  = 6,
  "FRJÁL" = 6.2,
  "SJÁLF" = 7.5,
  "IND"   = Inf
)

stopifnot(names(colors) == names(scores))
order = names(colors)[ order(scores) ]
