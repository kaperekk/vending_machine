import boto3
import logging
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)

class ProductReleaseComponent:
    def __init__(self) -> None:
        self.db_res = boto3.resource(
            "dynamodb", region_name='eu-central-1')
        self.menu_list = self.db_res.Table("menu_list")

    def add_new_item(self, data):
        message = "Add item succeded"
        try:
            response = self.menu_list.put_item(Item=data)
        except ClientError as err:
            message = f"Error while updating, {err.response['Error']['Code']}: {err.response['Error']['Message']}"
            logger.error(
                message
            )
        return message

    def update_items(self, id, product_list):
        message = ""
        try:
            response = self.menu_list.update_items(
                Key={"id": id},
                UpdateExpression="SET #I=:i",
                ExpressionAttributeNames={"#I": "items"},
                ExpressionAttributeValues={
                    ":i": product_list}
            )
        except ClientError as err:
            message = f"Error while updating, {err.response['Error']['Code']}: {err.response['Error']['Message']}"
            logger.error(
                message,
            )
        return message
