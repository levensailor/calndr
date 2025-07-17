from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
import uuid

from backend.db import models
from backend.schemas import theme as theme_schema
from backend.core.database import get_db
from backend.core.security import get_current_user

router = APIRouter()

@router.post("/", response_model=theme_schema.Theme)
def create_theme(theme: theme_schema.ThemeCreate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    db_theme = models.Theme(**theme.dict(), id=str(uuid.uuid4()), created_by_user_id=current_user.id)
    db.add(db_theme)
    db.commit()
    db.refresh(db_theme)
    return db_theme

@router.get("/", response_model=List[theme_schema.Theme])
def get_themes(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    return db.query(models.Theme).filter((models.Theme.is_public == True) | (models.Theme.created_by_user_id == current_user.id)).all()

@router.put("/{theme_id}", response_model=theme_schema.Theme)
def update_theme(theme_id: str, theme: theme_schema.ThemeUpdate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    db_theme = db.query(models.Theme).filter(models.Theme.id == theme_id).first()
    if db_theme is None:
        raise HTTPException(status_code=404, detail="Theme not found")
    if db_theme.created_by_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to update this theme")
    
    for var, value in vars(theme).items():
        if value is not None:
            setattr(db_theme, var, value)
    
    db.commit()
    db.refresh(db_theme)
    return db_theme

@router.delete("/{theme_id}", status_code=204)
def delete_theme(theme_id: str, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    db_theme = db.query(models.Theme).filter(models.Theme.id == theme_id).first()
    if db_theme is None:
        raise HTTPException(status_code=404, detail="Theme not found")
    if db_theme.created_by_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to delete this theme")
    
    db.delete(db_theme)
    db.commit()
    return

@router.put("/set-preference/{theme_id}", status_code=204)
def set_theme_preference(theme_id: str, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    user_prefs = db.query(models.UserPreference).filter(models.UserPreference.user_id == current_user.id).first()
    if user_prefs is None:
        user_prefs = models.UserPreference(user_id=current_user.id, selected_theme_id=theme_id)
        db.add(user_prefs)
    else:
        user_prefs.selected_theme_id = theme_id
    
    db.commit()
    return 