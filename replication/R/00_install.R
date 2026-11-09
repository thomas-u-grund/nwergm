# Installs the R packages in the versions used for the article (R 4.6.0).
# ergm 4.12.0 is the version nwergm 1.5.2 was compared with; newer versions may give slightly different numbers.
install.packages("remotes", repos = "https://cloud.r-project.org")
remotes::install_version("statnet.common", version = "4.13.0", repos = "https://cloud.r-project.org")
remotes::install_version("network", version = "1.20.0", repos = "https://cloud.r-project.org")
remotes::install_version("ergm", version = "4.12.0", repos = "https://cloud.r-project.org")
install.packages("coda", repos = "https://cloud.r-project.org")
