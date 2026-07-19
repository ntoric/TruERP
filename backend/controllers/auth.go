package controllers

import (
	"billbook/models"
	"billbook/utils"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/pquerna/otp/totp"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

type RegisterInput struct {
	Name     string `json:"name" binding:"required"`
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=6"`
	Phone    string `json:"phone"`
}

type LoginInput struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
	TotpCode string `json:"totp_code"`
}

func Register(c *gin.Context) {
	var input RegisterInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var existingUser models.User
	if err := utils.DB.Where("email = ?", input.Email).First(&existingUser).Error; err == nil {
		c.JSON(http.StatusConflict, gin.H{"error": "Email already registered"})
		return
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(input.Password), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to hash password"})
		return
	}

	user := models.User{
		ID:       uuid.New(),
		Name:     input.Name,
		Email:    input.Email,
		Password: string(hashedPassword),
		Phone:    input.Phone,
		Role:     "owner",
	}

	if err := utils.DB.Create(&user).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create user"})
		return
	}

	if err := EnsureDefaultChartOfAccounts(utils.DB, user.ID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to initialize accounting"})
		return
	}

	business := models.Business{
		ID:     uuid.New(),
		UserID: user.ID,
		Name:   input.Name + "'s Business",
	}
	utils.DB.Create(&business)

	utils.EnsureDefaultRoles(utils.DB, user.ID)

	token, err := utils.GenerateToken(user.ID, user.Name, user.Email, user.Role)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate token"})
		return
	}

	// Log registration
	CreateAuditLog(
		user.ID,
		user.Name,
		"register",
		"user",
		&user.ID,
		user.Email,
		"User registered new account",
		c.ClientIP(),
		c.GetHeader("User-Agent"),
		nil,
		"success",
		"",
	)

	c.JSON(http.StatusCreated, gin.H{
		"token": token,
		"user": gin.H{
			"id":    user.ID,
			"name":  user.Name,
			"email": user.Email,
			"phone": user.Phone,
			"role":               user.Role,
			"two_factor_enabled": user.TwoFactorEnabled,
		},
	})
}

func Login(c *gin.Context) {
	var input LoginInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var user models.User
	if err := utils.DB.Where("email = ?", input.Email).First(&user).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid email or password"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(input.Password)); err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid email or password"})
		return
	}

	if !user.IsActive {
		c.JSON(http.StatusForbidden, gin.H{"error": "Account is deactivated"})
		return
	}

	if user.TwoFactorEnabled {
		if input.TotpCode == "" {
			c.JSON(http.StatusUnauthorized, gin.H{
				"error":        "Two-factor authentication code required",
				"requires_2fa": true,
			})
			return
		}
		if !totp.Validate(input.TotpCode, user.TotpSecret) {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid two-factor code"})
			return
		}
	}

	token, err := utils.GenerateToken(user.ID, user.Name, user.Email, user.Role)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate token"})
		return
	}

	// Log login
	CreateAuditLog(
		user.ID,
		user.Name,
		"login",
		"user",
		&user.ID,
		user.Email,
		"User logged in",
		c.ClientIP(),
		c.GetHeader("User-Agent"),
		nil,
		"success",
		"",
	)

	c.JSON(http.StatusOK, gin.H{
		"token": token,
		"user": gin.H{
			"id":    user.ID,
			"name":  user.Name,
			"email": user.Email,
			"phone":              user.Phone,
			"role":               user.Role,
			"two_factor_enabled": user.TwoFactorEnabled,
		},
	})
}

func GetProfile(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var user models.User
	if err := utils.DB.Preload("Business").First(&user, "id = ?", userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"id":       user.ID,
		"name":     user.Name,
		"email":    user.Email,
		"phone":    user.Phone,
		"role":               user.Role,
		"two_factor_enabled": user.TwoFactorEnabled,
		"business":           user.Business,
	})
}

func UpdateProfile(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var input struct {
		Name  string `json:"name"`
		Phone string `json:"phone"`
	}
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if err := utils.DB.Model(&models.User{}).Where("id = ?", userID).Updates(map[string]interface{}{
		"name":  input.Name,
		"phone": input.Phone,
	}).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update profile"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Profile updated successfully"})
}
