package main

type Orders []Order

type Order struct {
	Group []Group `toml:"group"`
}

type Group struct {
	ID      string `toml:"id"`
	Version string `toml:"version"`
}

func (orders Orders) UpdateOrderDependencyVersion(dep Dependency) Orders {
	for i, order := range orders {
		for j, group := range order.Group {
			if group.ID == dep.ID {
				orders[i].Group[j].Version = dep.Version
			}
		}
	}

	return orders
}
