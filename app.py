# streamlit_app.py
import time
import streamlit as st
import modules.menu_component as menu_component
import modules.product_release_component as product_release_component


def main():
    st.title("Vending Machine Hello!")
    menu = ["Update item", "Add new item", "Remove item"]
    choice = st.sidebar.selectbox("Navigate", menu)

    if choice == "Update item amount/price":
        update_amount_price()
    elif choice == "Add item":
        add_item()
    elif choice == "Remove item":
        remove_item()


def remove_item():
    # Get machine ID from query parameter in the URL
    machine_id = st.experimental_get_query_params().get("id", ["1"])[0]

    # Get item list from database
    menu_comp = menu_component.MenuComponent()
    product_release_comp = product_release_component.ProductReleaseComponent()
    items = menu_comp.query_items(machine_id)

    # Display the selected machine item list
    st.header(f"Current Inventory for machine id {machine_id}:")
    st.table(items)

    # Allow user to edit the machine item list
    st.header("Remove Item from Inventory:")

    # User input for adding new item
    removing_item = st.selectbox(
        "Select item to remove:", list(items.keys()))

    # Remove item from dictionary
    items.pop(removing_item)

    # Display machine item list after change
    st.header(f"Updated Inventory for machine id {machine_id}:")
    st.table(items)

    # Confirm button to update the database
    if st.button("Confirm Update"):
        # Perform the database update (simulated by printing here)
        response = product_release_comp.update_items(
            machine_id, items)
        if response == "":
            response = "Update item succeded"
        output_container = st.empty()
        output_container.write(response)
        time.sleep(4)
        output_container.empty()


def add_item():
    # Get machine ID from query parameter in the URL
    machine_id = st.experimental_get_query_params().get("id", ["1"])[0]

    # Get item list from database
    menu_comp = menu_component.MenuComponent()
    product_release_comp = product_release_component.ProductReleaseComponent()
    items = menu_comp.query_items(machine_id)

    st.header(f"Inventory for machine id {machine_id}:")
    st.table(items)

    st.header("Add New Item to Inventory:")

    # Ask user for input
    new_item = st.text_input(
        "Enter new item to add:")
    new_quantity = st.number_input(
        "Enter quantity:", min_value=0, step=1)
    new_price = st.number_input(
        "Enter price:", min_value=0, step=1)

    # Update new item
    items[new_item] = {"amount": new_quantity, "price": new_price}

    # Display machine item list after change
    st.header(f"Updating inventory machine {machine_id}...")
    st.table(items)

    # Confirm DB update
    if st.button("Confirm Update"):
        response = product_release_comp.update_items(
            machine_id, items)
        if response == "":
            response = "Add item succeded"
        output_container = st.empty()
        output_container.write(response)
        time.sleep(5)
        output_container.empty()


def update_amount_price():
    # Get machine ID from query parameter in the URL
    machine_id = st.experimental_get_query_params().get("id", ["1"])[0]

    # Get item list from database
    menu_comp = menu_component.MenuComponent()
    product_release_comp = product_release_component.ProductReleaseComponent()
    items = menu_comp.query_items(machine_id)

    # Display the selected machine item list
    st.header(f"Current Inventory for machine id {machine_id}:")
    st.table(items)

    # Allow user to edit the machine item list
    st.header("Change Machine Inventory:")

    item_to_edit = st.selectbox(
        "Select item:", list(items.keys()))

    # Get the current values
    current_quantity = items[item_to_edit]['amount']
    current_price = items[item_to_edit]['price']

    # User input for editing
    new_quantity = st.number_input(
        "Enter new quantity:", min_value=0, value=int(current_quantity), step=1)
    new_price = st.number_input(
        "Enter new price:", min_value=0, value=int(current_price), step=1)

    # Notify user if there is change in quantity or price
    handle_quantity_change(new_quantity, current_quantity)
    handle_price_change(new_price, current_price)

    # Update the store_data dictionary
    items[item_to_edit]['amount'] = new_quantity
    items[item_to_edit]['price'] = new_price

    # Display machine item list after change
    st.header(f"Updated Inventory for machine id {machine_id}:")
    st.table(items)

    # Confirm change
    if st.button("Confirm Update"):
        # Update DB
        response = product_release_comp.update_items(
            machine_id, items)
        if not response:
            response = "Update values succeded"
        output_container = st.empty()
        output_container.write(response)
        time.sleep(4)
        output_container.empty()


def handle_quantity_change(quantity_input, initial_quantity):
    if quantity_input != initial_quantity:
        st.write(
            f"Quantity has changed from **{initial_quantity}** to **{quantity_input}**")


def handle_price_change(price_input, initial_price):
    if price_input != initial_price:
        st.write(
            f"Price has changed from **{initial_price}** to **{price_input}**")


if __name__ == "__main__":
    main()
