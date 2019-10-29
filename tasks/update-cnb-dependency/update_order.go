package main

type Order struct {
	Group []Group
}

type Group struct {
	ID      string
	Version string
}

func UpdateOrderDependencyVersion(orders []Order, dep Dependency) []Order {
	for i, order := range orders {
		for j, group := range order.Group {
			if group.ID == dep.ID {
				orders[i].Group[j].Version = dep.Version
			}
		}

	}

	return orders
}
