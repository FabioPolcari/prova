#' Computing supervised learning
#'
#' The function computes classification or regression depending on the variable given
#' in input. It shows performance metrics for each algorithm in order to allow
#' the user to asses which is the best one.
#'
#' @author Fabio Polcari & Matteo Ruggiero
#' @param data data.frame. Dataset on which algorithms are executed
#' @param Y character. Name of the dependent variable to regress/classify. If the variable is
#' a factor, it has to have 2 levels.
#' @param k numeric. Number of folds used in cross validation. It must me between 2 and
#' the number of observation.
#' @param alpha numeric. Vector (or single number) indicating the levels of alpha
#' used in penalized regression. Must be between 0 and 1.
#' @return A result matrix is returned. If the variable is numeric, the result is a
#' matrix showing R2 and RMSE values for every level of alpha specified as argument
#' in the function. If the variable is a factor, the result will be a matrix showing
#' accuracy, misclassification rate, F-score and Mattew coefficient for each different algorithm.
#' @import caret
#' @import glmnet
#' @import rsample
#' @import corrplot
#' @import factoextra
#' @import cluster
#' @import fpc
#' @import assertthat
#' @import tidyverse
#' @export

class_regr <- function( data, Y, k=5 , alpha = c(0, 0.2, 0.4, 0.6, 0.8, 1)){

  #error handling for x(dataset)
  assert_that( is.data.frame(data), msg = "x must be a data frame")

  #error handling Y
  assert_that(is.character(Y), msg = "Y must be a string")

  #we change name to the variable selected
  colnames(data)[which(colnames(data)==Y)] <- "y"
  #print(str(data))

  #error handling k
  assert_that(k<nrow(data), msg = "k cannot be bigger than the number of observations")
  assert_that(k>1, msg = "k must be at least equal to 2")

  #error handling alpha
  assert_that(any(is.vector(alpha), is.numeric(alpha), is.integer(alpha)),
              msg = "invalid input for alpha")

  for (i in 1:length(alpha)){
    assert_that(any(is.numeric(alpha[i]), is.integer(alpha)),
                msg = "alpha must be integer or numeric")
    assert_that(alpha[i]>=0 & alpha[i]<=1, msg = "alpha must be between 0 and 1")
  }

  # if x is factorial (classification)
  if (is.factor(data$y)){

    assert_that(length(table(data$y)) == 2, msg = "Y have to have 2 levels")

    set_kFCV <- trainControl(method="cv", number = k,    # cross-validation settings
                             savePredictions = "final",
                             classProbs = TRUE)

    # logistic regression
    kfcv_logistic <- train(y ~ ., data = data ,
                            trControl = set_kFCV,
                            method="glm", family=binomial())

    conf_matr_logistic <- table(kfcv_logistic$pred$obs, kfcv_logistic$pred$pred)

    accuracy_logistic <- (conf_matr_logistic[1,1] + conf_matr_logistic[2,2]) / nrow(data)
    misc_rate_logistic <- 1 - accuracy_logistic

    sensitivity <- conf_matr_logistic[2,2]/sum(conf_matr_logistic[, 2])
    recall <- conf_matr_logistic[2,2]/sum(conf_matr_logistic[2,])
    F_score_logistic   <- 2*(sensitivity*recall) / (sensitivity+recall)

    # lda regression
    kfcv_lda <- train(y ~ ., data = data ,
                           trControl = set_kFCV,
                           method="lda")


    conf_matr_lda <- table(kfcv_lda$pred$obs, kfcv_lda$pred$pred)

    accuracy_lda <- kfcv_lda$results$Accuracy

    misc_rate_lda <- 1 - accuracy_lda

    sensitivity <- conf_matr_lda[2,2]/sum(conf_matr_lda[, 2])
    recall <- conf_matr_lda[2,2]/sum(conf_matr_lda[2,])
    F_score_lda   <- 2*(sensitivity*recall) / (sensitivity+recall)

    # qda regression
    kfcv_qda <- train(y ~ ., data = data,
                      trControl = set_kFCV,
                      method="qda")

    conf_matr_qda <- table(kfcv_qda$pred$obs, kfcv_qda$pred$pred)

    accuracy_qda <- kfcv_qda$results$Accuracy

    misc_rate_qda <- 1 - accuracy_qda


    sensitivity <- conf_matr_qda[2,2]/sum(conf_matr_qda[, 2])
    recall <- conf_matr_qda[2,2]/sum(conf_matr_qda[2,])
    F_score_qda   <- 2*(sensitivity*recall) / (sensitivity+recall)

    # knn
    kfcv_knn <- train(y ~ ., data = data, method = "knn",
                      trControl = set_kFCV)

    conf_matr_knn <- table(kfcv_knn$pred$obs, kfcv_knn$pred$pred)

    accuracy_knn <- kfcv_knn$results$Accuracy[which.max(kfcv_knn$results$Accuracy)]

    misc_rate_knn <- 1 - accuracy_knn

    sensitivity <- conf_matr_knn[2,2]/sum(conf_matr_knn[, 2])
    recall <- conf_matr_knn[2,2]/sum(conf_matr_knn[2,])
    F_score_knn   <- 2*(sensitivity*recall) / (sensitivity+recall)


    # OUTPUT MATRIX

    result_matr <- matrix(0, ncol = 4, nrow = 3)
    result_matr[,1] <- c(accuracy_logistic, misc_rate_logistic, F_score_logistic)
    result_matr[,2] <- c(accuracy_qda, misc_rate_qda, F_score_qda)
    result_matr[,3] <- c(accuracy_lda, misc_rate_lda, F_score_lda)
    result_matr[,4] <- c(accuracy_knn, misc_rate_knn, F_score_knn)

    colnames(result_matr) <- c("logistic", "qda", "lda", "knn")
    rownames(result_matr) <- c("accuracy", "misc rate", "F-score")

    return(result_matr)

  # if x is numeric (regression)
  }else{

    data_split <- initial_split(data, prop = .7)
    data_train <- training(data_split)
    data_test  <- testing(data_split)

    x <- model.matrix(y ~ ., data_train)[,-1]
    y <- data_train$y

    x.test <- model.matrix(y ~ ., data_test)[,-1]
    results <- matrix(0, ncol=length(alpha), nrow = 2)
    colnames(results) <- rep("", length(alpha))

    for (i in 1:length(alpha)){

      cv <- cv.glmnet(x, y, alpha = alpha[i])
      mod <- glmnet(x, y, alpha = alpha[i], lambda = cv$lambda.min)
      predictions <- mod %>% predict(x.test) %>% as.vector()

      RMSE = RMSE(predictions, data_test$y)
      Rsquare = R2(predictions, data_test$y)

      results[1,i] <- RMSE
      results[2,i] <- Rsquare
      colnames(results)[i] <- as.character(alpha[i])

    }
    rownames(results) <- c("RMSE", "R2")    # output matrix
    return(results)
  }
}
