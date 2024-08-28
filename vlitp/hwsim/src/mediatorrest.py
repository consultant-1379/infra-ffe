import logging
import requests
import json

class MediatorREST:
    def __init__(self, url, deployment):
        """
        Set up session.
        """
        self.logger = logging.getLogger("MediatorREST")

        self.logger.debug("MediatorREST url=%s deployment=%s", url, deployment)
        self.deployment = deployment

        self.api_url = url
        self.sess = requests.Session()

    def request(self, endpoint, method='GET', data=None, return_response=False):
        url = "{0}{1}".format(self.api_url,endpoint)

        if data is None:
            data = {}
        data['deployment'] = self.deployment

        self.logger.info("request: endpoint=%s method=%s data=%s",endpoint, method, str(data))
        response = self.sess.request(method, url, json=data)
        self.logger.info("request: response status_code=%s",response.status_code)
        self.logger.debug("request: response.content=%s", response.content)
        if response.content is not None \
           and len(response.content) > 0 and 'content-type' in response.headers \
           and response.headers['content-type'] == 'application/json':
            self.logger.debug("request: json=%s",(json.dumps(response.json(), indent=4, sort_keys=True)))

        response.raise_for_status()

        if response.status_code == 200 or response.status_code == 201:
            if return_response:
                result = response
            else:
                result = response.json()
            return result
        else:
            raise Exception("Request failed with http_error={0}".format(response.status_code))
