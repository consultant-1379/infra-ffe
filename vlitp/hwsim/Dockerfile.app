FROM hwsim-base:0.0.1

WORKDIR /hwsim

COPY src/* src/
COPY run.sh .

ENTRYPOINT [ "/hwsim/run.sh" ]

