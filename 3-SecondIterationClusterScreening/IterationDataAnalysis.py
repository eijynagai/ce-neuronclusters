#!/usr/bin/env python3# -*- coding: utf-8 -*-"""Created on Tue Oct  1 11:26:43 2019@author: amandine"""import pandas as pdpath='IterationData.csv'df=pd.read_csv(path)# Identify the number of parent_cluster groupsnumberOfGroups=(df['parent_cluster'].unique())# Create an empty result file with columnsresult=pd.DataFrame(columns=['parent_cluster', 'cluster_id', 'cluster_lenght', 'occurence', 'method_list']) # Loop for each parent_cluster attributionfor group in numberOfGroups:         # create a new dataframe for each parent_cluster    data=df[df['parent_cluster']==group]        # create a 'method' column == combination of dim & resol    data['method']=df.apply(lambda row: (row['dim'], row['resol']), axis=1)        # transform string into list and alpha sorting    data.dropna(inplace = True)     data["cluster_id"]= data["cluster_id"].str.split(", ")    data["cluster_id"]=data['cluster_id'].sort_values().apply(lambda x: sorted(x)).transform(tuple)    # get unique pattern and make a list with them    patternList=list(data['cluster_id'].transform(tuple).unique())    patternList.sort(key=lambda t: len(t)) # sort by len of tuple        # loop for each pattern    for pattern in patternList:        # obtain the lenght of the pattern        patternLenght=len(pattern)        # obtain row corresponding to the pattern        dataPattern=data.loc[data['cluster_id'] == pattern]        # count number of rows with the pattern & unique combination of dim and resol (avoid overcounting if pattern is repeated several times in a same method)        numberOfPattern=dataPattern['method'].nunique()        # Get the list of all the method with the pattern        listOfMethod=dataPattern['method'].unique().tolist()        # Summarize the data in the empty result file        result=result.append({'parent_cluster':group, 'cluster_id':pattern, 'cluster_lenght':patternLenght, 'occurence':numberOfPattern, 'method_list':listOfMethod}, ignore_index=True)# Save the result as csvresult.to_csv('ClusterAnalysis.csv')#patternList=[list(elem) for elem in patternList]