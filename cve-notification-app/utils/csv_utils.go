package utils

import (
	"encoding/csv"
	"github.com/spf13/afero"
)

//go:generate go run github.com/maxbrunsfeld/counterfeiter/v6 . CSVUtilsInterface
type CSVUtilsInterface interface {
	GetDependenciesList() ([]DepList, error)
}

type CSVUtils struct {
	FilePath   string
	FileSystem afero.Fs
}

type DepList struct {
	Vendor  string
	Product string
}

func NewCSVUtils(filePath string) CSVUtils {
	return CSVUtils{filePath, afero.NewOsFs()}
}

func (csvU CSVUtils) GetDependenciesList() ([]DepList, error) {
	csvFile, err := csvU.FileSystem.Open(csvU.FilePath)
	if err != nil {
		return nil, err
	}

	reader := csv.NewReader(csvFile)

	if _, err := reader.Read(); err != nil {
		return nil, err
	}

	csvLines, err := reader.ReadAll()
	if err != nil {
		return nil, err
	}

	var deps []DepList

	for _, line := range csvLines {

		if line[4] != "" && line[5] != "" {
			deps = append(deps, DepList{
				Vendor:  line[4],
				Product: line[5],
			})
		}
	}

	return deps, nil
}
