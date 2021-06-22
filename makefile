all: cache

cache:
	docker build -t pwighton/bids-tools .
  
no-cache:
	docker build --no-cache -t pwighton/bids-tools .
