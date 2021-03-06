
### JMCode.R
### Function: This is code from Javadi, Javanmard, Montanari, and Schmit 
###           that provides inference for high dimensional regression
###           coefficients using the de-biased lasso introduced in
###           the paper
###           "Confidence intervals and hypothesis testing for 
###            high-dimensional regression", A. Javanmard, A. Montanari
###            2013, arXiv:1306.3171
###           We made modifications to their original code 
###           to (i) remove the computation of the p-value and the
###           length of the CI and (ii) to compute the projection of 
###           the inverse covariance matrix on to the design matrix.
###           
###           The code was obtained with permission from A. Javanmard.
###           and the link to the original code can be found here
###           https://web.stanford.edu/~montanar/sslasso/code.html
### Maintainer: Hyunseung Kang
### E-mail: hyunseung@stat.wisc.edu


# Authors: Hamid Javadi, Adel Javanmard, Andrea Montanari, Sven Schmit
# Date: April 24th, 2014
#
# Confidence intervals for high-dimensional regression using the method of
# A. Javanmard, A. Montanari
# "Confidence intervals and hypothesis testing for high-dimensional regression"
# 2013, arXiv:1306.3171
#
library(Matrix);
library(glmnet);
library(flare);

SoftThreshold <- function( x, lambda ) {
#
# Standard soft thresholding
#
  if (x>lambda){
    return (x-lambda);}
  else {
    if (x< (-lambda)){
      return (x+lambda);}
    else {
      return (0); }
  }
}

InverseLinftyOneRow <- function ( sigma, i, mu, maxiter=50, threshold=1e-2 ) {
  p <- nrow(sigma);
  rho <- max(abs(sigma[i,-i])) / sigma[i,i];
  mu0 <- rho/(1+rho);
  beta <- rep(0,p);
    
  if (mu >= mu0){
    beta[i] <- (1-mu0)/sigma[i,i];
    returnlist <- list("optsol" = beta, "iter" = 0);
    return(returnlist);
  }
  
  diff.norm2 <- 1;
  last.norm2 <- 1;
  iter <- 1;
  iter.old <- 1;
  beta[i] <- (1-mu0)/sigma[i,i];
  beta.old <- beta;
  sigma.tilde <- sigma;
  diag(sigma.tilde) <- 0;
  vs <- -sigma.tilde%*%beta;
  
  while ((iter <= maxiter) && (diff.norm2 >= threshold*last.norm2)){    
    
    for (j in 1:p){
      oldval <- beta[j];
      v <- vs[j];
      if (j==i)
        v <- v+1;    
      beta[j] <- SoftThreshold(v,mu)/sigma[j,j];
      if (oldval != beta[j]){
      	vs <- vs + (oldval-beta[j])*sigma.tilde[,j];
      }
    }
    
    iter <- iter + 1;
    if (iter==2*iter.old){
      d <- beta - beta.old;
      diff.norm2 <- sqrt(sum(d*d));
      last.norm2 <-sqrt(sum(beta*beta));
      iter.old <- iter;
      beta.old <- beta;
      if (iter>10)
         vs <- -sigma.tilde%*%beta;
    }
  }

  returnlist <- list("optsol" = beta, "iter" = iter)
  return(returnlist)
}

InverseLinfty <- function(sigma, n, resol=1.5, mu=NULL, maxiter=50, threshold=1e-2, verbose = TRUE) {
  isgiven <- 1;
  if (is.null(mu)){
  	isgiven <- 0;
  }

  p <- nrow(sigma);
  M <- matrix(0, p, p);
  xperc = 0;
  xp = round(p/10);
  for (i in 1:p) {
        if ((i %% xp)==0){
          xperc = xperc+10;
          if (verbose) {
            print(paste(xperc,"% done",sep="")); }
        }
  	if (isgiven==0){
  	  mu <- (1/sqrt(n)) * qnorm(1-(0.1/(p^2)));
  	}
  	mu.stop <- 0;
  	try.no <- 1;
  	incr <- 0;
  	while ((mu.stop != 1)&&(try.no<10)){
  	  last.beta <- beta
  	  output <- InverseLinftyOneRow(sigma, i, mu, maxiter=maxiter, threshold=threshold)
  	  beta <- output$optsol
  	  iter <- output$iter
  	  if (isgiven==1){
  	  	mu.stop <- 1
  	  }
  	  else{
            if (try.no==1){
              if (iter == (maxiter+1)){
                incr <- 1;
                mu <- mu*resol;
              } else {
                incr <- 0;
                mu <- mu/resol;
              }
            }
            if (try.no > 1){
              if ((incr == 1)&&(iter == (maxiter+1))){
                mu <- mu*resol;
              }
              if ((incr == 1)&&(iter < (maxiter+1))){
                mu.stop <- 1;
              }
              if ((incr == 0)&&(iter < (maxiter+1))){
                mu <- mu/resol;
              }
              if ((incr == 0)&&(iter == (maxiter+1))){
                mu <- mu*resol;
                beta <- last.beta;
                mu.stop <- 1;
              }                        
            }
          }
  	  try.no <- try.no+1
  	}
  	M[i,] <- beta;
  }
  return(M)
}

Lasso <- function( X, y, lambda = NULL, intercept = TRUE){
#
# Compute the Lasso estimator:
# - If lambda is given, use glmnet and standard Lasso
# - If lambda is not given, use square root Lasso
#
  p <- ncol(X);
  n <- nrow(X);
   
  if  (is.null(lambda)){
    lambda <- sqrt(qnorm(1-(0.1/p))/n);
    outLas <- slim(X,y,lambda=c(lambda),method="lq",q=2,verbose=FALSE);
                                        # Objective : sqrt(RSS/n) +lambda *penalty
    if (intercept==TRUE) {
      return (c(as.vector(outLas$intercept),as.vector(outLas$beta)))
    }  else {
      return (as.vector(outLas$beta));
    }
  } else {
    outLas <- glmnet(X, y, family = c("gaussian"), alpha =1, intercept = intercept );
                                        # Objective :1/2 RSS/n +lambda *penalty
    if (intercept==TRUE){
      return (as.vector(coef(Las,s=lambda)));
    } else {
      return (as.vector(coef(Las,s=lambda))[2:(p+1)]);
    }
  }
}

SSLasso <- function (X, y, lambda = NULL, mu = NULL, intercept = TRUE, 
                     resol=1.3, maxiter=50, threshold=1e-2, verbose = TRUE) {
#
# Compute confidence intervals and p-values.
#
# Args:
#   X     :  design matrix
#   y     :  response
#   lambda:  Lasso regularization parameter (if null, fixed by sqrt lasso)
#   mu    :  Linfty constraint on U (if null, searches)
#   intercept: Should the intercept term be included?
#   resol :  step parameter for the function that computes U
#   maxiter: iteration parameter for computing U
#   threshold : tolerance criterion for computing U
#   verbose : verbose?
#
# Returns:
#   coef    : Lasso estimated coefficients
#   unb.coef: Unbiased coefficient estimates
#   WUMat: projection of the inverse covariance matrix.
#   resid.lasso: residual based on Lasso
#
  p <- ncol(X);
  n <- nrow(X);
  pp <- p;
  col.norm <- 1/sqrt((1/n)*diag(t(X)%*%X));
  X <- X %*% diag(col.norm);

  # Solve Lasso problem using FLARE package
  htheta <- Lasso (X,y,lambda=lambda,intercept=intercept);
  
  # Format design matrix to include intercept and standardize.
  if (intercept==TRUE){
    Xb <- cbind(rep(1,n),X);
    col.norm <- c(1,col.norm);
    pp <- (p+1);
  } else {
    Xb <- X;
  }
  resid.lasso = (y - Xb %*% htheta)
  sigma.hat <- (1/n)*(t(Xb)%*%Xb);
  
  # Estimation of U (or M in Javanard and Montanari's original paper)
  # Check to see if this is a low dimensional problem
  if ((n>=2*p)){
	  tmp <- eigen(sigma.hat)
   	tmp <- min(tmp$values)/max(tmp$values)
  }else{
	  tmp <- 0
  }
  
  # If low-dimensional problem, use inverse of covariance as an estiamte of precision matrix
  # Otherwise, solve the convex optimizatio problem for U
  if ((n>=2*p)&&(tmp>=1e-4)){
	  U <- solve(sigma.hat)
  }else{
    U <- InverseLinfty(sigma.hat, n, resol=resol, mu=mu, maxiter=maxiter, threshold=threshold, verbose=verbose);
  }
  
  # Debias Lasso
  unbiased.Lasso <- as.numeric(htheta + (U%*%t(Xb)%*%(y - Xb %*% htheta))/n);
  
  # Scale them back to the original scaling.
  htheta <- htheta*col.norm;
  unbiased.Lasso <- unbiased.Lasso*col.norm;
  WUMat = Xb %*% t(U) %*% diag(col.norm)
  
  if (intercept==TRUE){
    htheta <- htheta[2:pp];
    unbiased.Lasso <- unbiased.Lasso[2:pp];
    WUMat <- WUMat[,2:pp]
  }  

  returnList <- list("coef" = htheta,
                     "unb.coef" = unbiased.Lasso,
                     "WUMat" = WUMat,
                     "resid.lasso" = resid.lasso)
  return(returnList)
}


