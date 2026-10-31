package main

import (
	"log"

	"github.com/GulseherB/hospital-appointment-system/backend/config"
	"github.com/GulseherB/hospital-appointment-system/backend/database"
	"github.com/gin-gonic/gin"
)

func main() {
	configuration, err := config.Load()
	if err != nil {
		log.Fatalf("configuration failed: %v", err)
	}

	db, err := database.Connect(configuration)
	if err != nil {
		log.Fatalf("database connection failed: %v", err)
	}

	sqlDB, err := db.DB()
	if err != nil {
		log.Fatalf("database handle failed: %v", err)
	}
	defer sqlDB.Close()

	if err := database.Migrate(db); err != nil {
		log.Fatalf("database migration failed: %v", err)
	}

	router := gin.Default()
	router.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})

	log.Printf("API listening on :%s", configuration.AppPort)
	if err := router.Run(":" + configuration.AppPort); err != nil {
		log.Fatalf("server failed: %v", err)
	}
}
