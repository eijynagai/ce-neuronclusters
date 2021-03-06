#best condition found in first iteration
PCs=92
Resols=4

#Load functions and datasets needed
source("InitializationScript.R")

#load clusters produced by best condition found in the first iteration
load("../2-PlotBestFirstClustering/CeNeurons_1st_seurat_clusters")
ClusToTest<-levels(CeNeurons_1st_seurat_clusters)


# This calculates a Stouffer combined z-score for each cell using
# scaled values of gen expression corresponding to the different 
# neuronal identities
databoxplot<-data.frame(row.names = names(CeNeurons_1st_seurat_clusters))
for (neuron in colnames(cured_brain_atlas_PL_and_OH)) { #for neuron in expression atlas 
  NeuronTest=scaled[c(getGenes(neuron)),] #get expression of genes corresponding to each neuron identity
  NeuronTest=apply(NeuronTest, 2, sum) #sum all the scores
  NeuronTest=NeuronTest/sqWheigtNeuron[neuron] # Second part of Stouffer's method calculation
  NeuronTest=NeuronTest[rownames(databoxplot)] #order cells
  databoxplot<-cbind(databoxplot,NeuronTest) #attach the calculated neuron score to databoxplot
  names(databoxplot)[names(databoxplot) == "NeuronTest"] = neuron #name column with neuron identity
}

######## iteration 
maxPCs=PCs
dims2test=1:12#expresed in fractions of the maximum PCs 

IterationData=data.frame()
for (parentcluster in ClusToTest[order(as.numeric(ClusToTest))]) {
  # clusterScreen <- FirstClusterScreen
  lsitaClusterFinal=list()
  cells=names(CeNeurons_1st_seurat_clusters[CeNeurons_1st_seurat_clusters == parentcluster])
  SubClusterScreen<-rawdata.neuronsALL[,cells] #get subset of cell rna counts
  
  #Creates Seurat Object
  SubClusterScreen <- CreateSeuratObject(counts = SubClusterScreen, min.cells = 0, min.features = 0, project = "Cao Neurons")
  
  SubClusterScreen <- NormalizeData(SubClusterScreen, normalization.method = "LogNormalize",scale.factor = 10000)
  
  SubClusterScreen <- FindVariableFeatures(SubClusterScreen, selection.method = "vst", nfeatures = 10000)
  
  all.genes <- rownames(SubClusterScreen)
  
  SubClusterScreen <- ScaleData(SubClusterScreen, features = all.genes,do.scale = TRUE,do.center = TRUE)
  
  if (length(cells) > maxPCs) {
    npcs = PCs
  } else{
    npcs = length(cells)-1
  }
  
  SubClusterScreen <- RunPCA(SubClusterScreen, npcs = npcs)
  
  # iterate changing number of dimensions and resolution parameters 
  for (proportionDims in dims2test) {
    
    dims=round(npcs/proportionDims)#As fractions of the maximum PCs 
    
    Resols = 1:30/10 #resol from 0.1 to 3
    for (SeuratResol in Resols) {
      testSeurat = FALSE
      testSeurat <- try(FindNeighbors(SubClusterScreen, reduction = "pca", dims = 1:dims),silent = TRUE)
      if (typeof(testSeurat) == "character") {
        break #if FindNeighbors fails this conditions are not tested
      }else{
        SubClusterScreen <-testSeurat
      }
      testSeurat = FALSE
      testSeurat <- try(FindClusters(SubClusterScreen, resolution = SeuratResol), silent = TRUE)
      if (typeof(testSeurat) == "character") {
        break #if FindClusters fails this conditions are not tested
      }else{
        SubClusterScreen <- testSeurat
      }
      
      cluster_id = list()# Neuronal identities in subcluster
      cluster_cells = list()# number of cells in cluster
      n_ident = list()# number of identities atumatically detected
      
      #get data from each subcluster in the subclutering condition
      for (cluster in levels(SubClusterScreen$seurat_clusters)) {
        #cell names
        cellsInCluster = names(SubClusterScreen$seurat_clusters[SubClusterScreen$seurat_clusters == cluster])
        # orden neurons by median score
        NeuronOrder = levels(reorder(colnames(databoxplot), apply(databoxplot[cellsInCluster,], 2, median)))
        # get score data
        data2test = databoxplot[cellsInCluster,rev(NeuronOrder)]
        
        # A sequential t-test from the highest to lowest ranked neuron classes
        # applied iteratively to the successive pair
        pvalues = rep(1,length(NeuronOrder))
        names(pvalues) = colnames(data2test)
        for (i in 1:(length(NeuronOrder)-1)) {
          # Try two sample t-test. 
          test = try(t.test(data2test[i], data2test[i+1], alternative = "greater"), silent = TRUE)#manage t.test error
          if (!is.list(test)) {
            break
          }
          pvalues[i] = test$p.value
          if (test$p.value < 0.05) {# If it fails set p-value = 1 (this happend in small clusters when cells have the same score)
            break
          }
        }
        
        # one sample t-test with mu=0 (in the scaled data zero is the mean)
        ptreshold <- apply(data2test, 2, FUN = tryTtest,alternative = "greater")
        ptreshold <- sapply(ptreshold, '[[', 'p.value')
        
        # FDR adjustment of the p-value
        FDRtreshold = p.adjust(ptreshold,method = "fdr")
        # Name of automatically detected identities
        totalIdentities = intersect(names(FDRtreshold[FDRtreshold < 0.05]), names(pvalues[pvalues < 1]))
        # number of cells in cluster
        CellNumber = length(cellsInCluster)
        
        # collect data in lists to for the IterationData
        cluster_id[cluster] = paste(totalIdentities,collapse = ", ")
        cluster_cells[cluster] = CellNumber
        n_ident[cluster] = length(totalIdentities)

      }
      # In each iteration for each cluster fill the iteration data
      IterationData <- rbind(IterationData,
                           data.frame(parent_cluster = parentcluster, #parent cluster used for the reclustering
                                      dim = dims,# number of dimensions used
                                      resol = SeuratResol,# resolution used
                                      subcluster = names(unlist(cluster_cells)),#subcluster id number
                                      n_cells = unlist(cluster_cells),# number of cells in cluster
                                      cluster_id = unlist(cluster_id),# Neuronal identities in subcluster
                                      n_ident = unlist(n_ident),# number of identities atumatically detected
                                      n_clusters = length(levels(SubClusterScreen$seurat_clusters))) # number of clusters produced in the iteration
      )
      }

    }
    
    
    
  }

### SAVE RESULTS
IterationData=unique(IterationData)
write.csv(IterationData,"IterationData.csv")
save(IterationData, file="IterationData.rda")

