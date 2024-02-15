import os
from google.cloud import storage

os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = 'ServiceKeyGoogleCloud.json'

storage_client = storage.Client()

##
## THIS CODE UPLOADS A FILE TO THE TEST TRANSFERS FOLDER IN KYS_DATA_BUCKET
##

my_bucket = storage_client.get_bucket('kys_data_bucket')

def upload_to_bucket(blob_name, path, bucket_name):
    try:
        bucket = storage_client.get_bucket(bucket_name)
        blob = bucket.blob(blob_name)
        blob.upload_from_filename(path)
        return True

    except Exception as e:
        print(e)
        return False

# Test Code
# file_path = 'C:/Users/Lenovo/Desktop/Python Projects/SocStream'
# upload_to_bucket('TestTransfers/TestFile', os.path.join(file_path,'TestFile.txt'),'kys_data_bucket')