import boto3


class MenuComponent:
    def __init__(self) -> None:
        self.db_res = boto3.resource(
            "dynamodb", region_name='eu-central-1')
        self.menu_list = self.db_res.Table("menu_list")

    def query_items(self, id):
        response = self.menu_list.get_items(Key={"id": id})
        return response["Item"]["items"]

    def get_items(self, id):
        return self.query_items(id=id)
