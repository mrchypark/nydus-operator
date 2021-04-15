
.PHONY: clean compile build apply greetings local

BONNY_IMAGE=mrchypark/nydus-operator

all: clean compile build apply

compile:
	mix deps.get
	mix compile

build:
	mix bonny.gen.dockerfile
	docker build -t ${BONNY_IMAGE} .
	docker push ${BONNY_IMAGE}:latest

local:
	rm manifest.yaml
	mix bonny.gen.manifest
	kubectl apply -f ./manifest.yaml
	iex -S mix

apply:
	mix bonny.gen.manifest --image ${BONNY_IMAGE}
	kubectl apply -f ./manifest.yaml
	kubectl get all

greetings:
	kubectl apply -f ./examples/external.yaml
	kubectl get all

clean:
	kubectl delete -f ./greetings.yaml
	sleep 5
	kubectl delete -f ./manifest.yaml
	rm manifest.yaml
	rm -rf mix.lock _build deps