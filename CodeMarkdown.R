library(corrplot)
library(cluster)
library(ggplot2)
library(caret)
library(randomForest)

root = "./statlog+vehicle+silhouettes/"
names = "a;b;c;d;e;f;g;h"

collname <- c("COMP", "CIRC", "DISTCIRC", "RADIUS", "PRAX", "MAXL", "SCAT", 
              "ELONG", "PRREC", "MAXREC", "SVMJAX", "SVMNAX", "SRG", "SKMIN", 
              "SKMAJ", "KURMIN", "KURMAJ", "HOL", "TYPE")


# Construct file paths
file_paths <- paste0(root, "xa", strsplit(names, ";")[[1]], ".dat")
file_paths
file_contents <- lapply(file_paths, readLines)

# Flatten the nested list into a single character vector
flattened_data <- unlist(file_contents)

# Split each row into individual columns based on spaces
split_data <- strsplit(flattened_data, "\\s+")

# Convert to a data frame
data_table <- do.call(rbind, split_data)

# Optionally, assign column names
colnames(data_table) <- paste0(collname)

combined_data <- as.data.frame(data_table)




histo_data <- combined_data

# Missing values check
sum(is.na(histo_data))
histo_data

# Change the type of the columns (except the last one) to numeric
histo_data[, 1:18] <- sapply(histo_data[, 1:18], as.numeric)

# Plot setup
par(mfrow = c(5, 4), mar = c(4, 4, 2, 1))  # Adjust layout and margins

# Example for compactness
# hist(histo_data$COMPACTNESS, 
#     main = "Distribution de la COMPACTNESS", 
#     xlab = "COMPACTNESS", 
#     col = "lightblue", 
#     border = "black")

histo_data_no_type = histo_data[, 1:18]
# Plot histograms for each variable
interesting_columns = c("COMP","CIRC","PRAX","SRG","SKMAJ","HOL")

# New window for boxplot
par(mfrow = c(3, 2), mar = c(4, 4, 2, 1))  # Adjust layout and margins

for (col_name in colnames(histo_data_no_type[, interesting_columns])) {
  hist(histo_data[[col_name]], 
       main = paste("Histogram of ", col_name), 
       xlab = col_name, 
       col = "lightblue", 
       border = "black")
}

# New window for boxplot
par(mfrow = c(1, 1), mar = c(4, 4, 2, 1))  # Reset layout and margins

boxplot(histo_data_no_type[, interesting_columns], 
        main = "Boxplot", 
        col = "lightblue", 
        border = "black")

# Correlation matrix
cor_matrix <- cor(histo_data[, interesting_columns])

# Heatmap of correlations
corrplot(cor_matrix, method = "color", type = "upper", 
         tl.cex = 0.8, tl.col = "black", 
         col = colorRampPalette(c("blue", "white", "red"))(200))

pairs(histo_data[, interesting_columns], pch = 19, col = rgb(0, 0, 1, 0.5))



# K-means clustering

library(cluster)


histo_data_no_type.km <- kmeans(histo_data_no_type, centers=3)
print(histo_data_no_type.km)

library(ggplot2)



#########################################################################
###########################     KMEANS    ##############################
#########################################################################


# Elbow method

elbow <- function(data, max_k = 10) {
  wss <- sapply(1:max_k, function(k){
    kmeans(data, k)$tot.withinss
  })
  plot(1:max_k, wss, type = "b", 
       xlab = "Number of clusters",
       ylab = "Within groups sum of squares")
}

elbow(histo_data_no_type)
# Elbow starts at 2 and ends at 5, plateau is at around 3

histo_data_no_type_copy <- histo_data_no_type
histo_data_no_type_copy$cluster <- as.factor(histo_data_no_type.km$cluster)
ggplot(histo_data_no_type_copy, aes(x = histo_data_no_type_copy$COMP, y = histo_data_no_type_copy$CIRC, color = cluster)) +
  geom_point() +
  labs(title = "K-means Clustering Results")


#########################################################################
###########################       PAM      ##############################
#########################################################################



# Sample of 100 rows
#histo_data_no_type_100_sample <- histo_data_no_type
histo_data_no_type_100_sample <- histo_data_no_type[sample(1:nrow(histo_data_no_type), 100), ]
histo_data_no_type.pam <- pam(histo_data_no_type_100_sample, k=5)
print(histo_data_no_type.pam)
plot(histo_data_no_type.pam)
# We have a good diagram first but also good silhouette with 'high' values meaning that the clusters are well separated

# Function to calculate silhouette scores
calculate_silhouette <- function(data, max_clusters = 10) {
  silhouette_scores <- sapply(2:max_clusters, function(k) {
    km <- kmeans(data, centers = k)
    ss <- silhouette(km$cluster, dist(data))
    mean(ss[, 3])
  })
  plot(2:max_clusters, silhouette_scores, 
       type = "b", 
       xlab = "Number of Clusters", 
       ylab = "Average Silhouette Score")
}

calculate_silhouette(histo_data_no_type)

#########################################################################
###########################       CAH      ##############################
#########################################################################



#Dendrogram on 100 samples from before
histo_data_no_type_scaled <- scale(histo_data_no_type)
distance_matrix <- dist(histo_data_no_type_scaled)
histo_data_no_type_scaled.hc <- hclust(distance_matrix, method = "ward.D2")
plot(histo_data_no_type_scaled.hc)
# We get a good dendrogram with 3 obvious clusters, we could also try with 4 clusters

cutTree_3_clust <- cutree(histo_data_no_type_scaled.hc, k = 3) # We desire 3 groups
cutTree_4_clust <- cutree(histo_data_no_type_scaled.hc, k = 4) # We desire 4 groups

# Display the number of elements in each cluster
table(cutTree_3_clust)
#  1   2   3 
# 376 214 162 
table(cutTree_4_clust)
#  1   2   3   4 
# 376 206   8 162 
# Wreirdly, one of the branches of the 4 cluster is relatively small, so I would consider to chose 3 clusters.

cent_3 <- NULL
for(k in 1:3) {
  cent_3 <- rbind(cent_3, colMeans(histo_data_no_type_scaled[cutTree_3_clust == k, , drop = FALSE]))
}
cent_3

# Hierarchical clustering on centroids (centroid linkage)
cent_hc <- hclust(dist(cent_3), method = "cen")

# Plot the original and new dendrogram (based on centroids)
opar <- par(mfrow = c(1, 2))  # Set layout to display two plots
plot(histo_data_no_type_scaled.hc, labels = FALSE, hang = -1, main = "Original Dendrogram")
plot(cent_hc, labels = FALSE, hang = -1, main = "Dendrogram of Centroids")
par(opar)  # Restore the original plot layout


### ADD THE TYPE BACK

histo_data$TYPE <- as.factor(histo_data$TYPE)

set.seed(42)
histo_data.km <- kmeans(histo_data_no_type, centers = 4, nstart = 10)

# Add cluster labels
histo_data$Cluster_KM <- as.factor(histo_data.km$cluster)




set.seed(42)
histo_data.pam <- pam(histo_data_no_type, k = 4)
# Add cluster labels
histo_data$Cluster_PAM <- as.factor(histo_data.pam$clustering)


histo_data_scaled <- scale(histo_data_no_type)
distance_matrix <- dist(histo_data_scaled)

histo_data.hc <- hclust(distance_matrix, method = "ward.D2")
plot(histo_data.hc, main = "Dendrogram")

cut_clusters <- cutree(histo_data.hc, k = 3)
histo_data$Cluster_HC <- as.factor(cut_clusters)


table(histo_data$Cluster_KM, histo_data$TYPE)
table(histo_data$Cluster_PAM, histo_data$TYPE)
table(histo_data$Cluster_HC, histo_data$TYPE)


#########################################################################
###########################   Supervised   ##############################
#########################################################################


set.seed(42)

# Prepare the data
# Get indices for each vehicle type
bus_indices <- which(histo_data$TYPE == "bus")
opel_indices <- which(histo_data$TYPE == "opel")
saab_indices <- which(histo_data$TYPE == "saab")
van_indices <- which(histo_data$TYPE == "van")

# Sample 80% of indices for each type
c <- c(
  sample(bus_indices, round(0.8 * length(bus_indices))),
  sample(opel_indices, round(0.8 * length(opel_indices))),
  sample(saab_indices, round(0.8 * length(saab_indices))),
  sample(van_indices, round(0.8 * length(van_indices)))
)

# Fit the tree
fit <- rpart(TYPE ~ ., data = histo_data, subset = c, method = "class")

# Use rpart.plot for visualization
rpart.plot(fit, 
           main = "Classification Tree for Vehicle Types",
           extra = 106,  # Show predicted class and percentage
           fallen.leaves = TRUE)

# Predict on the remaining data (test set)
predictions <- predict(fit, histo_data[-c, ], type = "class")
confusion_matrix <- table(predictions, histo_data$TYPE[-c])
print("Confusion Matrix:")
print(confusion_matrix)

# Calculate accuracy
accuracy <- sum(diag(confusion_matrix)) / sum(confusion_matrix)
print(paste("Accuracy:", round(accuracy * 100, 2), "%"))

